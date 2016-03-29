use "collections"
use "time"

trait BenchTest
  fun ref setup() =>
    None
  fun ref empty() =>
    None
  fun ref run() =>
    None
  fun ref teardown() =>
    None

trait BenchResultHandler
  be emptyIterations(duration: F64, std_dev: F64)
  be benchIterations(duration: F64, std_dev: F64)

trait BenchStatusNotify
  be done()
  be iteration()

actor _DefaultStatusNotify is BenchStatusNotify
  be done() => None
  be iteration() => None

class BenchTimerNotifier is TimerNotify
  let _runner: BenchRunner tag
  new create(runner': BenchRunner tag) => _runner = runner'
  fun ref apply(timer: Timer, count: U64): Bool =>
    _runner._stop()
    false

actor BenchRunner
  let _timers: Timers = Timers
  let _test: BenchTest iso
  let _handler: BenchResultHandler tag
  let _status: BenchStatusNotify tag
  let _iterations: U64
  let _run_length: U64
  var _stopping: Bool = false
  var _count: U64 = 0
  var _duration: U64 = 0
  var _m: F64 = 0.0
  var _n: F64 = 0.0
  var _s: F64 = 0.0

  new create(test: BenchTest iso,
      handler: BenchResultHandler tag,
      iterations: U64 = 1000,
      run_length: U64 = 10_000_000_000,
      status: (None | BenchStatusNotify tag) = None)
      =>
    _test = consume test
    _handler = handler
    _status = match status
    | let s: BenchStatusNotify tag => s
    else
      _DefaultStatusNotify
    end
    _iterations = iterations
    _run_length = run_length

  be apply() =>
    _reset()
    _stopping = false
    _timers( Timer(recover BenchTimerNotifier(this) end, _run_length) )
    _run_empty()

  be _run_empty() =>
    if not _stopping then
      var i: U64 = 0
      let start = Time.perf_begin()
      while i < _iterations do
        _test.setup()
        _test.empty()
        _test.teardown()
        i = i + 1
      end
      _duration = _duration + (Time.perf_end() - start)
      _count = _count + _iterations
      _run_empty()
    else
      this._phase_one(_duration.f64() / _count.f64())
    end

  be _phase_one(i: F64) =>
    _status.iteration()
    _update_statistics(i)
    let mean = _mean()
    let std_dev = _std_dev()
    if (_n > 2) or (std_dev < (mean * 0.1)) then
      _handler.emptyIterations(i, std_dev)
      _reset()
      _stopping = false
      _timers( Timer(recover BenchTimerNotifier(this) end, _run_length) )
      _run_once()
    else
      _stopping = false
      _timers( Timer(recover BenchTimerNotifier(this) end, _run_length) )
      _run_empty()
    end

  be _run_once() =>
    if not _stopping then
      var i: U64 = 0
      let start = Time.perf_begin()
      while i < _iterations do
        _test.setup()
        _test.run()
        _test.teardown()
        i = i + 1
      end
      _duration = _duration + (Time.perf_end() - start)
      _count = _count + _iterations
      _run_once()
    else
      this._phase_two(_duration.f64() / _count.f64())
    end

  be _phase_two(i: F64) =>
    _status.iteration()
    _update_statistics(i)
    let mean = _mean()
    let std_dev = _std_dev()
    if (_n > 2) or (std_dev < (mean * 0.1)) then
      _handler.benchIterations(i, std_dev)
      _status.done()
    else
      _stopping = false
      _timers( Timer(recover BenchTimerNotifier(this) end, _run_length) )
      _run_once()
    end

  be _stop() =>
    _stopping = true

  be _reset() =>
    _duration = 0
    _count = 0
    _m = 0.0
    _s = 0.0
    _n = 0.0

  fun ref _update_statistics(k: F64) =>
    if _n == 0.0 then
      _m = k
      _s = 0.0
      _n = 1.0
    else
      _n = _n + 1.0
      let old_mean = _m
      _m = _m + ((k - _m) / _n)
      _s = _s + ((k - old_mean) * (k - _m))
    end

  fun _mean(): F64 => _m
  fun _std_dev(): F64 => (_s / (_n - 1)).sqrt()
