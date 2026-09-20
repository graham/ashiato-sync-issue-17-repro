#pragma once

// THE CHORE ROTA: work an autopilot -- or any other machine that thinks for itself -- does now
// and then rather than every tick, spread over the ticks so that adding machines does not add
// a spike, and held to a budget so that adding many of them stretches the waits rather than
// the tick.
//
// Asked for on 2026-09-14 in the user's words: "roughly every 10 ticks but not more than 60
// ticks, and a callback", and "splay them out" so that "it doesn't overload the system for
// every ai fsm that gets added". Before this each autopilot kept two float countdowns of its
// own -- a look along its flight path every half second and a re-check of its leg every three
// -- phased off its seed and with nothing anywhere to say how many ran on one tick.
//
// A KIND is how often a chore wants doing (`target_ticks`), how late it may ever be
// (`max_ticks`), and how many of it one tick will pay for (`budget`). A CHORE is one kind of
// work for one thing, named by a 64-bit id the caller owns.
//
// THE RULES, each of them a promise a test holds:
//
// - A chore comes due `target_ticks` after it was last served, give or take a jitter hashed
//   from (stream, kind, cycle). Hashed and not drawn, so a world that is started twice serves
//   the same chores on the same ticks, and nothing depends on the order a hash map iterates.
// - Each tick serves the chores that are due MOST URGENT FIRST, by DEADLINE -- the last serve
//   plus the limit, earliest first, which within one kind with nothing urgent is simply whoever
//   was served longest ago -- up to the kind's budget.
// - A chore that has waited `max_ticks` is FORCED, over budget if it has to be, and counted as
//   an overrun. So no interval is ever longer than `max_ticks`, and a budget too small for the
//   work shows up as a number rather than as a machine that stopped looking.
// - An URGENT chore comes due on `urgent_ticks` and is forced at `urgent_max_ticks`: a machine
//   with a threat flagged is served sooner even when the rota is full. Coming due sooner alone
//   was not enough -- it waited behind every older chore, 40 ticks against an urgent limit of
//   12 in `cockpit/tests/rota.gd`, exactly as long as before it was flagged.
//
// A COUNT OR A SHARE, NOT MICROSECONDS. A budget in time would serve different chores on
// different ticks depending on what else the machine was running, and two identical worlds would
// disagree -- on this workstation, with five other lanes running Godot, they always would. A share
// of what is registered, in integer millionths, is as deterministic as a count. Time is measured
// and reported by whoever serves the rota; it decides nothing.
//
// No Godot in here, on purpose: it is a data structure with a clock, and the clock is whatever
// frame number the caller hands it.

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <limits>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

namespace ashiato_gd::cockpit {

struct ChoreKind {
    std::string name;
    /// How often the chore wants doing, in ticks, before jitter.
    std::uint32_t target_ticks = 10;
    /// The longest it may ever wait between two serves. Forced at this, over budget if need be.
    std::uint32_t max_ticks = 60;
    /// How many of this kind one tick serves before only forced ones are served.
    std::uint32_t budget = std::numeric_limits<std::uint32_t>::max();
    /// OR A SHARE of the chores registered to the kind, in millionths: while non-zero it stands in
    /// for `budget` as ceil(registered x share), and never less than one. "Only do some percentage
    /// of the planes per tick", in the user's words. In integers, so it is exact and the same on
    /// every machine.
    std::uint32_t share_ppm = 0;
    /// Each interval is the target plus or minus up to this many ticks, hashed per cycle.
    std::uint32_t jitter_ticks = 0;
    /// The target while a chore is flagged urgent.
    std::uint32_t urgent_ticks = 1;
    /// The limit while it is urgent. DERIVED in `add_kind` -- the urgent target with the same
    /// slack the kind has between its target and its limit -- and whatever is passed is ignored.
    std::uint32_t urgent_max_ticks = 1;
};

/// What one kind has done since it was added or last reset. Intervals are between two real
/// serves of the same chore; a chore's first serve after it was added has no interval.
struct ChoreStats {
    std::uint64_t served = 0;
    std::uint64_t overruns = 0;
    std::uint64_t intervals = 0;
    std::uint64_t interval_sum = 0;
    std::uint32_t worst_interval = 0;
    std::uint32_t served_last_tick = 0;
    std::uint32_t served_most_in_a_tick = 0;
    std::uint64_t ticks = 0;
};

class ChoreRota {
public:
    using Kind = std::uint16_t;
    static constexpr Kind kNoKind = std::numeric_limits<Kind>::max();

    /// Adds a kind, or refuses one that cannot keep its own promise: no target, a target past
    /// its limit, or a name already taken. Jitter and the urgent target are clamped inside the
    /// limit here, once, so serving never has to ask.
    Kind add_kind(ChoreKind kind) {
        if (kind.target_ticks == 0 || kind.max_ticks < kind.target_ticks || kind.name.empty()
            || find_kind(kind.name) != kNoKind || kinds_.size() >= kNoKind) {
            return kNoKind;
        }
        derive_limits(kind);
        kinds_.push_back(Book{kind, {}, {}});
        grow_wheel(kind.max_ticks);
        return static_cast<Kind>(kinds_.size() - 1);
    }

    Kind find_kind(const std::string& name) const {
        for (std::size_t i = 0; i < kinds_.size(); ++i) {
            if (kinds_[i].kind.name == name) {
                return static_cast<Kind>(i);
            }
        }
        return kNoKind;
    }

    std::size_t kind_count() const { return kinds_.size(); }
    const ChoreKind& kind(Kind k) const { return kinds_[k].kind; }
    const ChoreStats& stats(Kind k) const { return kinds_[k].stats; }

    /// A count a tick, which clears any share.
    bool set_budget(Kind k, std::uint32_t budget) {
        if (k >= kinds_.size()) {
            return false;
        }
        kinds_[k].kind.budget = budget;
        kinds_[k].kind.share_ppm = 0;
        return true;
    }

    /// A share of the registered chores a tick, in millionths, which replaces any count.
    bool set_share(Kind k, std::uint32_t share_ppm) {
        if (k >= kinds_.size() || share_ppm == 0 || share_ppm > 1000000u) {
            return false;
        }
        kinds_[k].kind.share_ppm = share_ppm;
        return true;
    }

    /// A new limit, never under the target. Every chore of the kind is re-timed at once: one
    /// already queued is queued again under its new deadline, and one waiting in the wheel past
    /// the new limit is brought forward to it. Its generation is moved, so the old entries are
    /// passed over; a chore already in a batch being served is still served (see `serve`).
    bool set_limit(Kind k, std::uint32_t max_ticks) {
        if (k >= kinds_.size() || max_ticks < kinds_[k].kind.target_ticks) {
            return false;
        }
        ChoreKind& kind = kinds_[k].kind;
        kind.max_ticks = max_ticks;
        derive_limits(kind);
        grow_wheel(max_ticks);
        for (std::uint32_t slot = 0; slot < chores_.size(); ++slot) {
            Chore& c = chores_[slot];
            if (!c.alive || c.kind != k) {
                continue;
            }
            c.generation = ++generations_;
            if (c.eligible) {
                queue(slot);
                continue;
            }
            const std::uint64_t latest =
                c.last + (c.urgent ? kind.urgent_max_ticks : kind.max_ticks);
            if (c.due > latest) {
                c.due = std::max(cursor_ + 1, latest);
            }
            file(slot);
        }
        return true;
    }

    /// What this tick will pay for: the count, or the share of what is registered now.
    std::uint32_t budget_now(Kind k) const {
        const Book& book = kinds_[k];
        if (book.kind.share_ppm == 0) {
            return book.kind.budget;
        }
        const std::uint64_t parts =
            static_cast<std::uint64_t>(book.registered) * book.kind.share_ppm;
        return std::max<std::uint32_t>(1u, static_cast<std::uint32_t>((parts + 999999u) / 1000000u));
    }

    /// Put `id` on the rota for `k`, first due within one target of `now`, phased off the
    /// stream so that a crowd added on one tick does not come due on one tick. `stream` is what
    /// the jitter is hashed from: something about the thing that stays put when unrelated things
    /// are added, which an entity id handed out in spawn order is not.
    bool add(std::uint64_t id, Kind k, std::uint64_t stream, std::uint64_t now) {
        if (k >= kinds_.size() || index_.count(Key{id, k}) != 0) {
            return false;
        }
        begin_at(now);
        std::uint32_t slot;
        if (!free_.empty()) {
            slot = free_.back();
            free_.pop_back();
        } else {
            slot = static_cast<std::uint32_t>(chores_.size());
            chores_.emplace_back();
        }
        Chore& c = chores_[slot];
        c = Chore{};
        c.id = id;
        c.stream = stream;
        c.kind = k;
        c.alive = true;
        c.generation = ++generations_;
        c.last = now;
        const std::uint32_t target = kinds_[k].kind.target_ticks;
        c.due = now + 1 + mix(stream, k, 0xFFFFFFFFu) % target;
        index_[Key{id, k}] = slot;
        ++kinds_[k].registered;
        file(slot);
        return true;
    }

    bool remove(std::uint64_t id, Kind k) {
        const auto found = index_.find(Key{id, k});
        if (found == index_.end()) {
            return false;
        }
        Chore& c = chores_[found->second];
        c.alive = false;
        c.generation = ++generations_;
        --kinds_[k].registered;
        free_.push_back(found->second);
        index_.erase(found);
        return true;
    }

    /// Everything on the rota for `id`, whatever kind: what a machine that has gone needs.
    std::size_t remove_all(std::uint64_t id) {
        std::size_t removed = 0;
        for (std::size_t k = 0; k < kinds_.size(); ++k) {
            removed += remove(id, static_cast<Kind>(k)) ? 1 : 0;
        }
        return removed;
    }

    bool has(std::uint64_t id, Kind k) const { return index_.count(Key{id, k}) != 0; }

    /// Flag or clear urgency. Flagging brings a waiting chore's next serve forward to its last
    /// serve plus the urgent target, if that is sooner, and its deadline to the urgent limit;
    /// clearing puts the deadline back and lets the current wait stand.
    bool set_urgent(std::uint64_t id, Kind k, bool urgent, std::uint64_t now) {
        const auto found = index_.find(Key{id, k});
        if (found == index_.end()) {
            return false;
        }
        Chore& c = chores_[found->second];
        if (c.urgent == urgent) {
            return true;
        }
        c.urgent = urgent;
        if (c.eligible) {
            // Already queued, under the deadline it had: queue it again under the new one.
            c.generation = ++generations_;
            queue(found->second);
            return true;
        }
        if (urgent) {
            const std::uint64_t sooner =
                std::max(now + 1, c.last + kinds_[k].kind.urgent_ticks);
            if (sooner < c.due) {
                c.due = sooner;
                c.generation = ++generations_;
                file(found->second);
            }
        }
        return true;
    }

    std::uint32_t registered(Kind k) const { return kinds_[k].registered; }
    std::size_t waiting(Kind k) const { return kinds_[k].heap.size(); }

    /// A fold of every serve's (tick, kind, id), in the order served. Two worlds that serve the
    /// same chores on the same ticks have the same digest.
    std::uint64_t digest() const { return digest_; }

    void reset_stats() {
        for (Book& book : kinds_) {
            book.stats = ChoreStats{};
        }
        digest_ = kDigestSeed;
    }

    /// Forget every kind and chore. Generations keep counting, so a serve in progress -- a
    /// callback that tears the world down -- finds nothing it had in hand still valid.
    void clear() {
        kinds_.clear();
        chores_.clear();
        free_.clear();
        index_.clear();
        wheel_.clear();
        digest_ = kDigestSeed;
        cursor_ = 0;
        started_ = false;
    }

    /// Serve tick `now`. Ticks must be handed over in order; a gap is caught up tick by tick,
    /// so nothing filed on a skipped tick is left in the wheel.
    ///
    /// `serve(kind, id, waited)` is called for each chore served, kind by kind in the order
    /// the kinds were added and most urgent first within one. Every chore in a kind's batch is
    /// taken off the heap and given its next due tick BEFORE any callback runs, so a callback
    /// may add, remove or flag chores -- its own included -- or clear the rota outright.
    ///
    /// Not re-entrant: a callback that serves the rota again is refused and does nothing.
    template <typename Serve>
    void serve(std::uint64_t now, Serve&& serve_one) {
        if (wheel_.empty() || serving_) {
            return;
        }
        struct Serving {
            bool& flag;
            explicit Serving(bool& f) : flag(f) { flag = true; }
            ~Serving() { flag = false; }
        } serving(serving_);
        begin_at(now == 0 ? 0 : now - 1);
        const std::uint64_t mask = wheel_.size() - 1;
        // The wheel is one limit wide, so a gap longer than that has already been read once
        // round; catching up past it would only read the same slots again.
        if (now > cursor_ + wheel_.size()) {
            cursor_ = now - wheel_.size();
        }
        while (cursor_ < now) {
            ++cursor_;
            std::vector<Filed>& bucket = wheel_[cursor_ & mask];
            for (std::size_t i = 0; i < bucket.size();) {
                const Filed filed = bucket[i];
                if (!valid(filed)) {
                    bucket[i] = bucket.back();
                    bucket.pop_back();
                    continue;
                }
                Chore& c = chores_[filed.slot];
                if (c.due > cursor_) {
                    ++i;
                    continue;
                }
                bucket[i] = bucket.back();
                bucket.pop_back();
                c.eligible = true;
                queue(filed.slot);
            }
        }
        for (std::size_t k = 0; k < kinds_.size(); ++k) {
            Book& book = kinds_[k];
            const ChoreKind& kind = book.kind;
            // Read once, before anything is served: a callback that changes it -- or removes
            // chores, which moves a share -- changes the next tick's, not this one's.
            const std::uint32_t budget = budget_now(static_cast<Kind>(k));
            batch_.clear();
            std::uint32_t served = 0;
            while (!book.heap.empty()) {
                const Queued top = book.heap.front();
                if (!valid(Filed{top.slot, top.generation})) {
                    std::pop_heap(book.heap.begin(), book.heap.end(), Later{});
                    book.heap.pop_back();
                    continue;
                }
                const std::uint64_t waited = now - chores_[top.slot].last;
                const bool forced = now >= top.deadline;
                // Earliest deadline first: once the nearest is neither due under budget nor
                // forced, nobody behind it is either. Inside one kind with nothing urgent, every
                // limit is the same, so this is simply whoever was served longest ago.
                if (served >= budget && !forced) {
                    break;
                }
                std::pop_heap(book.heap.begin(), book.heap.end(), Later{});
                book.heap.pop_back();
                if (served >= budget) {
                    ++book.stats.overruns;
                }
                ++served;
                Chore& c = chores_[top.slot];
                if (c.cycle > 0) {
                    const auto interval = static_cast<std::uint32_t>(waited);
                    ++book.stats.intervals;
                    book.stats.interval_sum += interval;
                    book.stats.worst_interval = std::max(book.stats.worst_interval, interval);
                }
                c.eligible = false;
                c.last = now;
                ++c.cycle;
                c.due = now + next_wait(c);
                c.generation = ++generations_;
                file(top.slot);
                digest_ = (digest_ ^ now) * kDigestPrime;
                digest_ = (digest_ ^ k) * kDigestPrime;
                digest_ = (digest_ ^ c.id) * kDigestPrime;
                batch_.push_back(Served{top.slot, c.generation, c.id,
                                        static_cast<std::uint32_t>(waited)});
            }
            book.stats.served += served;
            book.stats.served_last_tick = served;
            book.stats.served_most_in_a_tick =
                std::max(book.stats.served_most_in_a_tick, served);
            ++book.stats.ticks;
            // By index and re-checked each time: nothing a callback can reach touches `batch_`
            // (serving again is refused), but it can remove, re-flag, re-time or clear what is in
            // it. Checked by WHO it is -- alive, same id, same kind -- and not by generation: a
            // callback that flags another chore urgent or changes the kind's limit moves the
            // generation of every chore it touches, and one already in hand must still be served.
            for (std::size_t i = 0; i < batch_.size(); ++i) {
                const Served s = batch_[i];
                if (s.slot < chores_.size() && chores_[s.slot].alive && chores_[s.slot].id == s.id
                    && chores_[s.slot].kind == static_cast<Kind>(k)) {
                    serve_one(static_cast<Kind>(k), s.id, s.waited);
                }
                if (k >= kinds_.size()) {
                    return;
                }
            }
        }
    }

private:
    struct Chore {
        std::uint64_t id = 0;
        std::uint64_t stream = 0;
        std::uint64_t last = 0;
        std::uint64_t due = 0;
        std::uint64_t generation = 0;
        std::uint32_t cycle = 0;
        Kind kind = 0;
        bool alive = false;
        bool urgent = false;
        bool eligible = false;
    };
    struct Filed {
        std::uint32_t slot;
        std::uint64_t generation;
    };
    struct Queued {
        /// The tick it is forced on: its last serve plus its limit, urgent or not.
        std::uint64_t deadline;
        std::uint32_t tie;
        std::uint64_t id;
        std::uint32_t slot;
        std::uint64_t generation;
    };
    /// std::push_heap keeps the LARGEST on top, so "later" is the larger: the nearest deadline
    /// comes out first, then the hashed tie, then the id, which makes the order total.
    struct Later {
        bool operator()(const Queued& a, const Queued& b) const {
            if (a.deadline != b.deadline) {
                return a.deadline > b.deadline;
            }
            if (a.tie != b.tie) {
                return a.tie > b.tie;
            }
            return a.id > b.id;
        }
    };
    struct Served {
        std::uint32_t slot;
        std::uint64_t generation;
        std::uint64_t id;
        std::uint32_t waited;
    };
    struct Book {
        ChoreKind kind;
        ChoreStats stats;
        std::vector<Queued> heap;
        std::uint32_t registered = 0;
    };
    struct Key {
        std::uint64_t id;
        Kind kind;
        bool operator==(const Key& o) const { return id == o.id && kind == o.kind; }
    };
    struct KeyHash {
        std::size_t operator()(const Key& key) const {
            return static_cast<std::size_t>(key.id * 0x9E3779B97F4A7C15ull ^ key.kind);
        }
    };

    static constexpr std::uint64_t kDigestSeed = 1469598103934665603ull;
    static constexpr std::uint64_t kDigestPrime = 1099511628211ull;

    /// A 32-bit hash of (stream, kind, cycle), written out rather than std::hash, whose values
    /// are the standard library's business and move with it.
    static std::uint32_t mix(std::uint64_t stream, std::uint32_t kind, std::uint32_t cycle) {
        std::uint64_t h = stream * 0x9E3779B97F4A7C15ull;
        h ^= (static_cast<std::uint64_t>(kind) << 32) ^ cycle;
        h ^= h >> 33;
        h *= 0xFF51AFD7ED558CCDull;
        h ^= h >> 33;
        h *= 0xC4CEB9FE1A85EC53ull;
        h ^= h >> 33;
        return static_cast<std::uint32_t>(h);
    }

    /// An urgent chore is not jittered: a quarter of the target either way could be all of its
    /// urgent period.
    std::uint32_t next_wait(const Chore& c) const {
        const ChoreKind& kind = kinds_[c.kind].kind;
        if (c.urgent) {
            return kind.urgent_ticks;
        }
        std::int64_t wait = kind.target_ticks;
        if (kind.jitter_ticks > 0) {
            const std::uint32_t span = kind.jitter_ticks * 2 + 1;
            wait += static_cast<std::int64_t>(mix(c.stream, c.kind, c.cycle) % span)
                - static_cast<std::int64_t>(kind.jitter_ticks);
        }
        return static_cast<std::uint32_t>(
            std::clamp<std::int64_t>(wait, 1, static_cast<std::int64_t>(kind.max_ticks)));
    }

    /// Jitter and the urgent limit, from the target and the limit, whenever either is set.
    static void derive_limits(ChoreKind& kind) {
        // No wider than would reach zero or pass the limit: a jitter the clamp cuts off at one
        // end is a jitter whose mean is no longer the target.
        kind.jitter_ticks = std::min({kind.jitter_ticks, kind.target_ticks - 1,
                                      kind.max_ticks - kind.target_ticks});
        kind.urgent_ticks = std::clamp<std::uint32_t>(kind.urgent_ticks, 1, kind.target_ticks);
        // AN URGENT CHORE HAS A NEARER LIMIT TOO, or urgency means nothing under contention: the
        // queue is served by deadline, and a chore that only came due sooner would wait behind
        // every older one exactly as long as it did before it was flagged.
        kind.urgent_max_ticks = static_cast<std::uint32_t>(std::clamp<std::uint64_t>(
            static_cast<std::uint64_t>(kind.urgent_ticks) * kind.max_ticks / kind.target_ticks,
            kind.urgent_ticks, kind.max_ticks));
    }

    /// The wheel is read from the tick after the first one anything happened on, so a chore
    /// added before the first serve is not filed in a slot the cursor has already passed.
    void begin_at(std::uint64_t tick) {
        if (!started_) {
            cursor_ = tick;
            started_ = true;
        }
    }

    bool valid(const Filed& filed) const {
        return filed.slot < chores_.size() && chores_[filed.slot].alive
            && chores_[filed.slot].generation == filed.generation;
    }

    /// Onto its kind's heap, under the deadline it has now.
    void queue(std::uint32_t slot) {
        const Chore& c = chores_[slot];
        Book& book = kinds_[c.kind];
        const std::uint64_t limit = c.urgent ? book.kind.urgent_max_ticks : book.kind.max_ticks;
        book.heap.push_back(Queued{c.last + limit, mix(c.stream, c.kind, c.cycle), c.id, slot,
                                   c.generation});
        std::push_heap(book.heap.begin(), book.heap.end(), Later{});
    }

    void file(std::uint32_t slot) {
        const Chore& c = chores_[slot];
        wheel_[c.due & (wheel_.size() - 1)].push_back(Filed{slot, c.generation});
    }

    /// One slot per tick of the longest limit, rounded up to a power of two. A due tick is
    /// never more than one limit ahead, so no slot holds two laps of the wheel at once.
    void grow_wheel(std::uint32_t max_ticks) {
        std::size_t size = 1;
        while (size <= max_ticks + 1u) {
            size <<= 1;
        }
        if (size <= wheel_.size()) {
            return;
        }
        std::vector<std::vector<Filed>> grown(size);
        for (auto& bucket : wheel_) {
            for (const Filed& filed : bucket) {
                if (valid(filed)) {
                    grown[chores_[filed.slot].due & (size - 1)].push_back(filed);
                }
            }
        }
        wheel_ = std::move(grown);
    }

    std::vector<Book> kinds_;
    std::vector<Chore> chores_;
    std::vector<std::uint32_t> free_;
    std::unordered_map<Key, std::uint32_t, KeyHash> index_;
    std::vector<std::vector<Filed>> wheel_;
    std::vector<Served> batch_;
    std::uint64_t generations_ = 0;
    std::uint64_t digest_ = kDigestSeed;
    std::uint64_t cursor_ = 0;
    bool started_ = false;
    bool serving_ = false;
};

}  // namespace ashiato_gd::cockpit
