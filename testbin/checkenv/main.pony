actor Main
  fun normkey(key: String): String =>
    ifdef windows then
      key.upper()
    else
      key
    end

  new create(env: Env) =>
    try
      match env.args.size()
      | 2 => // compare key with arg
        let key_want = normkey(env.args(1)?)
        for e in env.vars().values() do
          let parts = e.split_by("=", 2)
          if (parts.size() == 2)
            and (normkey(parts(0)?) == key_want)
          then
            return
          end
        end
        env.exitcode(1)
      | 3 => // compare key and value with args
        let key_want = normkey(env.args(1)?)
        let val_want = env.args(2)?
        for e in env.vars().values() do
          let parts = e.split_by("=", 2)
          if (parts.size() == 2)
            and (normkey(parts(0)?) == key_want)
            and (parts(1)? == val_want) then
            return
          end
        end
        env.exitcode(1)
      else
        error
      end
    else
      env.exitcode(2)
    end
