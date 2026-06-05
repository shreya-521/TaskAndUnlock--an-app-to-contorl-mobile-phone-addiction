# Task And Unlock - Optimized System Architecture
# Power Efficient & Storage Optimized Design

## 📋 Core Principle
**Lazy Activation**: The app only activates monitoring WHEN a blocked app is opened. Zero background processing otherwise.

---

## 🏗️ Optimized Architecture Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                    EVENT TRIGGER LAYER                        │
├──────────────────────────────────────────────────────────────┤
│  User Opens Instagram (or any blocked app)                   │
│                │                                              │
│                ▼                                              │
│  Native OS Broadcasts App Foreground Event                   │
│                │                                              │
│                └──────────────────────────────────────────┐   │
└──────────────────────────────────────────────────────────┼───┘
                                                          │
                        ┌─────────────────────────────────┘
                        │
        ┌───────────────▼────────────────────┐
        │   TaskAndUnlock Receives Event      │
        │   (Only when needed)                │
        └───────────────┬────────────────────┘
                        │
        ┌───────────────▼────────────────────┐
        │   Check Database (Single Query)     │
        │   - Is this app blocked?            │
        │   - Today's usage time?             │
        │   - Is usage > limit?               │
        └───────────────┬────────────────────┘
                        │
        ┌───────────────▼────────────────────┐
        │   Decision Point                    │
        ├───────────────┬────────────────────┤
        │               │                    │
        NO LIMIT    USAGE OK           USAGE EXCEEDED
        │               │                    │
        │               ▼                    ▼
        │           Allow App            Show Exercise
        │           to Open              Screen (Camera)
        │               │                    │
        │               │                    ▼
        │               │              Detect Pushups/Jumps
        │               │              Count Reps
        │               │                    │
        │               │                    ▼
        │               │          Update DB (2-3 writes)
        │               │          Unlock for 5 min
        │               │                    │
        │               └────────┬───────────┘
        │                        │
        └────────────────────────▼─────────────────┐
                                 │                 │
                        ┌────────▼─────────┐      │
                        │ Store in Memory  │      │
                        │ for 5 min        │      │
                        │ (LIGHTWEIGHT)    │      │
                        └──────────────────┘      │
                                                  │
                        ┌─────────────────────────┘
                        │
                ┌───────▼──────────────────┐
                │ After 5 min Unlock:      │
                │ Relock & Monitor Again   │
                │ (Same as above)          │
                └──────────────────────────┘
```

---

## ⚡ Power & Storage Optimization Strategy

### 1. **NO Persistent Background Service**
✓ USED: Native OS event listeners (app focus change)
✓ USED: Triggered checks ONLY on app open
✓ USED: In-memory timers (lightweight)

✗ NOT USED: Foreground Services
✗ NOT USED: Background Jobs (continuous polling)
✗ NOT USED: GPS tracking

### 2. **Minimal Database Writes**
Write to DB only when:
- New app opened (first time)
- Usage limit exceeded
- Exercise completed
- Daily reset (once per 24h)

### 3. **In-Memory Timer System**
- Lightweight in-memory approach
- Uses ~50 bytes per app
- Backup in SharedPreferences for app restart

### 4. **Minimal Storage Footprint**
- ~500 KB-1 MB total for years of data
- No video persistence (process in-memory, delete)
- Optimized DB schema

### 5. **Camera Optimization**
- 15 FPS sampling (sufficient for exercise detection)
- 480p resolution (lightweight, accurate)
- Process frames in-memory (no storage)
- Delete video after exercise (not persistent)

---

## 🔄 Event-Driven Flow (Power Efficient)

### Timeline: User Opens Instagram

```
00:00ms   User opens Instagram
00:10ms   OS reports foreground app change
00:20ms   TaskAndUnlock wakes up
00:30ms   Check: "Is Instagram in blocklist?" (~10ms query)
00:50ms   Check: "Usage today < limit?" (~10ms query)
01:00ms   DECISION: Can user open app? YES ✓
01:10ms   Allow app to open
        └──── APP RUNNING (TaskAndUnlock sleeping)
        
Next event only triggers when:
- Instagram closed → Background app
- Timer expires (if was unlocked)
- Another blocked app opened
```

### Timeline: App Usage Exceeds Limit

```
User tries to open Instagram (30+ min used today)
    │
    ▼
TaskAndUnlock checks usage: 30 >= 30 ✓
    │
    ▼
BLOCKED! Show Exercise Screen
    │
    ▼
Start Camera (ML Kit loads once)
    │
    ▼
Process video frames (15 FPS, 480p)
    │
    ▼
Detect 5 pushups completed ✓
    │
    ▼
Update Database (3 writes):
  1. Insert exercise record
  2. Update daily_usage table
  3. Update unlock session
    │
    ▼
Set In-Memory Timer: Unlocked for 5 minutes
    │
    ▼
Close Camera, Stop Processing
    │
    ▼
Allow Instagram to open
    │
    └──── TaskAndUnlock SLEEPS

After 5 minutes:
- Next time user tries Instagram
- Check: Is 5-min timer expired?
- Yes → Lock and repeat cycle
```

---

## 📊 Optimized Database Schema

### blocked_apps Table
```sql
CREATE TABLE blocked_apps (
  id INTEGER PRIMARY KEY,
  packageName TEXT UNIQUE NOT NULL,
  appName TEXT NOT NULL,
  dailyLimitMinutes INTEGER DEFAULT 30,
  isActive INTEGER DEFAULT 1,
  createdAt TEXT NOT NULL
  -- REMOVED: icon BLOB (saves ~100-500 KB)
);
```

### daily_usage Table
```sql
CREATE TABLE daily_usage (
  id INTEGER PRIMARY KEY,
  appId INTEGER NOT NULL,
  date TEXT NOT NULL,
  totalMinutes INTEGER DEFAULT 0,
  UNIQUE(appId, date)
);
-- Storage: ~22 bytes per entry
-- 365 days × 10 apps = 80 KB per year
```

### exercises Table
```sql
CREATE TABLE exercises (
  id INTEGER PRIMARY KEY,
  type TEXT NOT NULL,
  repsRequired INTEGER NOT NULL,
  repsCompleted INTEGER NOT NULL,
  completedAt TEXT NOT NULL,
  unlockedUntil TEXT NOT NULL,
  unlockedUntilMinutes INTEGER DEFAULT 5
  -- REMOVED: videoPath (saves ~1-10 MB per video)
);
-- Storage: ~72 bytes per record
-- 100 exercises/month = 7.2 KB
```

---

## ⚡ Power Consumption Breakdown

### Daily Power Usage (Optimized)

```
Per App Open (when checking):
- Native event wake: ~1 mJ
- DB query (5-10ms): ~5 mJ
- CPU processing: ~10 mJ
- Total per check: ~20 mJ
- 5 checks × 20 mJ = 100 mJ

Per Exercise (when over limit):
- Camera on (30 sec): ~500 mJ
- ML Kit processing (30 sec): ~200 mJ
- Total: ~700 mJ

Daily Total: ~1000 mJ
Percentage of daily battery: ~0.1-0.5% (NEGLIGIBLE)

Compare to:
- Instagram: ~10-15% per day
- This app: ~0.1% per day
```

---

## 💾 Storage Efficiency

### Traditional Approach:
- Continuous logging: 100 MB/month
- Video storage: 500 MB/month
- Total: ~700 MB/month

### Optimized Approach:
- Aggregated daily stats: 50 KB/month
- In-memory processing: 0 bytes stored
- No video persistence: 0 bytes
- Total: ~50 KB/month

**Savings: 99.9% reduction**

---

## 🎯 Implementation Key Points

### 1. Native Integration (Minimal)
- Triggered ONLY on app focus change
- No continuous polling
- No background service running

### 2. In-Memory State Management
- Keep only current session in memory
- ~100 bytes for 10 apps
- Persistence backup in SharedPreferences (~500 bytes)

### 3. Smart Database Cleanup
- Weekly cleanup job (runs for 5 seconds)
- Delete records older than 90 days
- Keep last 3 months of data

### 4. Exercise Processing
- ML Kit pose detection on-device
- Process at 15 FPS, 480p resolution
- Delete frames immediately
- Video only in memory (30-60 seconds)

---

## 📈 Resource Usage Summary

| Resource | Usage | Impact |
|----------|-------|--------|
| Battery | ~0.1-0.5% daily | Negligible |
| Storage | ~500 KB-1 MB | Tiny |
| RAM | ~50-150 MB (when active) | Standard |
| Network | 0 bytes | None (offline) |
| CPU | 5-10% (when checking) | Brief spikes only |

---

## ✅ What TO Do

```
✓ Listen to OS app focus events only
✓ Use in-memory timers
✓ Process ML on-device, delete immediately
✓ Keep data local only
✓ Load ML model on-demand (lazy)
✓ Use 15 FPS, 480p for detection
✓ Aggregate DB writes
✓ Clean old data monthly
```

---

## ❌ What NOT to Do

```
✗ Don't use background services
✗ Don't poll continuously
✗ Don't save full videos
✗ Don't sync to cloud
✗ Don't keep GPS active
✗ Don't use high-frequency sensors
✗ Don't load ML model at startup
```
