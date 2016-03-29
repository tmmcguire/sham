# sham
Simple Pony benchmarking framework

## Use

A simple, sample benchmark run is:

    use "sham"

    class SimpleTest is BenchTest

    actor Main is BenchResultHandler
      let env: Env
      let benchRunner: BenchRunner
    
      new create(env': Env) =>
        env = env'
        benchRunner = BenchRunner(RobinHoodAddRemoveTest, this)
        benchRunner()
    
      be emptyIterations(count: F64, std_dev: F64) =>
        env.out.print("empty: " + count.string() + " ± " + (std_dev * 2.0).string())
    
      be benchIterations(count: F64, std_dev: F64) =>
        env.out.print("bench: " + count.string() + " ± " + (std_dev * 2.0).string())

