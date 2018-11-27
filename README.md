# Exake

A simple tool like rake

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `exake` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:exake, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/exake](https://hexdocs.pm/exake).


## Usage

```elixir

defmodule RunATask do
  use Exake

  task :hello do
    IO.puts("hello")
  end
  task :world, with: [:hello] do
    IO.puts("world")
  end
end

Mix.Task.run("world")
# hello
# world

```

You can find more sample in `test/exake_test.exs`
