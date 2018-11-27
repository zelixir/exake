defmodule ExakeTest do
  use ExUnit.Case

  test "run a task" do
    defmodule RunATask do
      use Exake

      task :hello do
        send(:"run a task", "hi")
      end
    end

    Process.register(self(), :"run a task")
    Mix.Task.run("hello")
    assert_receive "hi"
  end

  test "run a task with namespace" do
    defmodule RunATaskWithNamespace do
      use Exake, namespace: :say

      task :default do
        send(:"run a task", "hello")
      end

      task :hello do
        send(:"run a task", "hi")
      end
    end

    Process.register(self(), :"run a task")
    Mix.Task.run("say")
    assert_receive "hello"
    Mix.Task.run("say.hello")
    assert_receive "hi"
  end

  test "tasks can have a description and document" do
    assert Mix.Task.shortdoc(Mix.Task.get!("task_doc")) == "This is a short doc"
    assert Mix.Task.moduledoc(Mix.Task.get!("task_doc")) == "This is a module doc"
    assert Mix.Task.shortdoc(Mix.Task.get!("task_doc2")) == "This is another short doc"
    assert Mix.Task.moduledoc(Mix.Task.get!("task_doc2")) == "This is another module doc"
  end

  test "run task with depedence" do
    defmodule RunTasksWithDependence do
      use Exake

      task :dep1 do
        send(:"run task with deps", {:greet, "greet by dep1"})
      end

      task :dep2 do
        send(:"run task with deps", {:greet, "greet by dep2"})
      end

      task :dep3, with: [:dep1, "dep2"] do
        send(:"run task with deps", {:greet, "greet by dep3"})
      end
    end

    Process.register(self(), :"run task with deps")
    Mix.Task.run("dep3")

    assert (receive do
              {:greet, str} -> str
            end) == "greet by dep1"

    assert (receive do
              {:greet, str} -> str
            end) == "greet by dep2"

    assert (receive do
              {:greet, str} -> str
            end) == "greet by dep3"
  end

  test "run task with arguments" do
    defmodule RunTaskWithArguments do
      use Exake

      task simple_arg(name) do
        send(:"run task with arguments", name: name)
      end

      task arg_with_aliases(name: :n) do
        send(:"run task with arguments", name: name)
      end

      task arg_with_default_string_value(value: "ok") do
        send(:"run task with arguments", value: value)
      end

      task arg_with_default_integer_value(value: 1) do
        send(:"run task with arguments", value: value)
      end

      task arg_with_default_float_value(value: 1.0) do
        send(:"run task with arguments", value: value)
      end

      task arg_with_default_boolean_value(value: :boolean) do
        send(:"run task with arguments", value: value)
      end

      task arg_with_alias_and_default_value(value: {:v, 1}) do
        send(:"run task with arguments", value: value)
      end

      task arg_with_args(name, args: ...) do
        send(:"run task with arguments", name: name, args: args)
      end

      task call_deps_with_args(a1: 1, a2: 2.0, a3: "ok", a4: :boolean),
        with: [
          arg_with_default_integer_value(value: a1),
          arg_with_default_float_value(value: a2),
          simple_arg(name: a3),
          arg_with_default_boolean_value(value: a4),
          :arg_with_default_string_value,
          arg_with_args(name: a3, args: [a3 <> "_ex" | ~w{hello world}])
        ] do
        send(:"run task with arguments", a1: a1, a2: a2, a3: a3, a4: a4)
      end
    end

    Process.register(self(), :"run task with arguments")

    Mix.Task.rerun("call_deps_with_args", ~w{--a1 123 --a2 22.34 --a3 ex --a4})
    assert_receive value: 123
    assert_receive value: 22.34
    assert_receive name: "ex"
    assert_receive value: true
    assert_receive value: "ok"
    assert_receive name: "ex", args: ~w{ex_ex hello world}

    Mix.Task.rerun("simple_arg")
    assert_receive name: nil
    Mix.Task.rerun("simple_arg", ~w{--name myname})
    assert_receive name: "myname"

    Mix.Task.rerun("arg_with_aliases")
    assert_receive name: nil
    Mix.Task.rerun("arg_with_aliases", ~w{--name myname})
    assert_receive name: "myname"
    Mix.Task.rerun("arg_with_aliases", ~w{-n myname})
    assert_receive name: "myname"

    Mix.Task.rerun("arg_with_default_string_value")
    assert_receive value: "ok"
    Mix.Task.rerun("arg_with_default_string_value", ~w{--value myname})
    assert_receive value: "myname"

    Mix.Task.rerun("arg_with_default_integer_value")
    assert_receive value: 1
    Mix.Task.rerun("arg_with_default_integer_value", ~w{--value 123})
    assert_receive value: 123

    Mix.Task.rerun("arg_with_default_float_value")
    assert_receive value: 1.0
    Mix.Task.rerun("arg_with_default_float_value", ~w{--value 123.4})
    assert_receive value: 123.4

    Mix.Task.rerun("arg_with_default_boolean_value")
    assert_receive value: false
    Mix.Task.rerun("arg_with_default_boolean_value", ~w{--value})
    assert_receive value: true

    Mix.Task.rerun("arg_with_alias_and_default_value")
    assert_receive value: 1
    Mix.Task.rerun("arg_with_alias_and_default_value", ~w{--value 2})
    assert_receive value: 2
    Mix.Task.rerun("arg_with_alias_and_default_value", ~w{-v 2})
    assert_receive value: 2

    Mix.Task.rerun("arg_with_args")
    assert_receive name: nil, args: []
    Mix.Task.rerun("arg_with_args", ~w{--name myname})
    assert_receive name: "myname", args: []
    Mix.Task.rerun("arg_with_args", ~w{ a b c })
    assert_receive name: nil, args: ~w{a b c}
    Mix.Task.rerun("arg_with_args", ~w{--name myname a b c })
    assert_receive name: "myname", args: ~w{a b c}
  end
end
