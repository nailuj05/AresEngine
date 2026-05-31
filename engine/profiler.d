module engine.profiler;

version(Profile)
{
    import std.datetime.stopwatch : StopWatch;

    struct Profiler {
        StopWatch sw;

        void start() {
            sw.reset();
            sw.start();
        }

        ulong stop() {
            return sw.peek.total!"usecs";
        }
    }
}
else
{
    struct Profiler {
        void start() {}
        ulong stop() { return 0; }
    }
}
