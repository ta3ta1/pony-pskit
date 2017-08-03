use "ponytest"
use ".."

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)
  new make() => None

  fun tag tests(test: PonyTest) =>
    test(PSKitSpawnMalformedCommandTest)
    test(PSKitSpawnNotFoundTest)
    test(PSKitSpawnBasicTest)

class iso PSKitSpawnMalformedCommandTest is UnitTest
  fun name(): String => "pskit/spawn.PSKitSpawn.MalformedCommand"

  fun apply(h: TestHelper) =>
    h.assert_error({() ? =>
      PSKitSpawn(
        h.env.root as AmbientAuth,
        object iso is PSKitSpawnNotify end,
        ""
      )?
    })

class iso PSKitSpawnNotFoundTest is UnitTest
  fun name(): String => "pskit/spawn.PSKitSpawn.NotFound"

  fun apply(h: TestHelper) ? =>
    PSKitSpawn(
      h.env.root as AmbientAuth,
      object iso is PSKitSpawnNotify
        fun opened() => h.fail_action("notfound")
        fun not_opened(errno: I32) =>
          h.complete_action("notfound")
          h.assert_eq[String](this.strerror(2), this.strerror(errno))
      end,
      "testbin/notexists"
    )?

    h.expect_action("notfound")
    h.long_test(1_000_000_000) // 1sec

  fun ref timed_out(h: TestHelper) =>
    h.complete(false)

class iso PSKitSpawnBasicTest is UnitTest
  fun name(): String => "pskit/spawn.PSKitSpawn.Basic"

  fun apply(h: TestHelper) ? =>
    // just run
    PSKitSpawn(
      h.env.root as AmbientAuth,
      object iso is PSKitSpawnNotify
        fun opened() => h.complete_action("hello")
        fun not_opened(errno: I32) => h.fail_action("hello")
        fun finished(exitcode: I32) => h.assert_eq[I32](0, exitcode)
      end,
      "testbin/hello"
    )?

    // arg/env
    PSKitSpawn(
      h.env.root as AmbientAuth,
      object iso is PSKitSpawnNotify
        fun opened() => h.complete_action("checkenv.no_env")
        fun not_opened(errno: I32) => h.fail_action("checkenv.no_env")
        fun finished(exitcode: I32) => h.assert_eq[I32](1, exitcode)
      end,
      "testbin/checkenv",
      recover ["PSKIT_SPAWN_TEST"] end
    )?

    PSKitSpawn(
      h.env.root as AmbientAuth,
      object iso is PSKitSpawnNotify
        fun opened() => h.complete_action("checkenv.has_env_key")
        fun not_opened(errno: I32) => h.fail_action("checkenv.has_env_key")
        fun finished(exitcode: I32) => h.assert_eq[I32](0, exitcode)
      end,
      "testbin/checkenv",
      recover ["PSKIT_SPAWN_TEST"] end,
      recover ["PSKIT_SPAWN_TEST=SOME"] end
    )?

    PSKitSpawn(
      h.env.root as AmbientAuth,
      object iso is PSKitSpawnNotify
        fun opened() => h.complete_action("checkenv.has_env_val")
        fun not_opened(errno: I32) => h.fail_action("checkenv.has_env_val")
        fun finished(exitcode: I32) => h.assert_eq[I32](0, exitcode)
      end,
      "testbin/checkenv",
      recover ["PSKIT_SPAWN_TEST"; "SOME"] end,
      recover ["PSKIT_SPAWN_TEST=SOME"] end
    )?

    PSKitSpawn(
      h.env.root as AmbientAuth,
      object iso is PSKitSpawnNotify
        fun opened() => h.complete_action("checkenv.has_env_diffval")
        fun not_opened(errno: I32) => h.fail_action("checkenv.has_env_diffval")
        fun finished(exitcode: I32) => h.assert_eq[I32](1, exitcode)
      end,
      "testbin/checkenv",
      recover ["PSKIT_SPAWN_TEST"; "SOME"] end,
      recover ["PSKIT_SPAWN_TEST=NONE"] end
    )?

    h.expect_action("hello")
    h.expect_action("checkenv.no_env")
    h.expect_action("checkenv.has_env_key")
    h.expect_action("checkenv.has_env_val")
    h.expect_action("checkenv.has_env_diffval")
    h.long_test(5_000_000_000) // 5sec

  fun ref timed_out(h: TestHelper) =>
    h.complete(false)
