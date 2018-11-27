defmodule Exake do
  defmacro __using__(opts) do
    Module.put_attribute(__CALLER__.module, :namespace, opts[:namespace])

    quote do
      import unquote(__MODULE__)
    end
  end

  @all_alias [?a..?z, ?A..?Z]
             |> Enum.flat_map(& &1)
             |> Enum.map(&[&1])
             |> Enum.map(&to_string/1)
             |> Enum.map(&String.to_atom/1)
  defp get_default_value_define(value) when is_integer(value), do: {:integer, value}
  defp get_default_value_define(value) when is_float(value), do: {:float, value}
  defp get_default_value_define(value) when is_binary(value), do: {:string, value}
  defp get_default_value_define(:boolean), do: {:boolean, false}
  defp get_default_value_define(), do: {:string, nil}

  defp get_arg_define({name, _, _}) when is_atom(name),
    do: {name, nil, get_default_value_define()}

  defp get_arg_define({name, alias}) when alias in @all_alias, do: {name, alias, {:string, nil}}

  defp get_arg_define({name, {alias, default}}) when alias in @all_alias do
    {name, alias, get_default_value_define(default)}
  end

  defp get_arg_define({name, {:..., _, _}}), do: {name, nil, {:argv, []}}
  defp get_arg_define({name, value}), do: {name, nil, get_default_value_define(value)}

  defp get_task_name_and_args(name) when is_atom(name), do: {name, []}

  defp get_task_name_and_args({name, _, args}) when is_atom(name),
    do: {name, args |> Enum.flat_map(&List.wrap/1) |> Enum.map(&get_arg_define/1)}

  defp get_module_name(name, namespace) do
    name =
      {namespace, "#{name}"}
      |> case do
        {nil, name} -> name
        {ns, "default"} -> "#{ns}"
        {ns, name} -> "#{ns}.#{name}"
      end
      |> Mix.Utils.command_to_module_name()

    Module.concat(Mix.Tasks, name)
  end

  defp get_args_ast(args) do
    get_args_ast =
      args
      |> Enum.map(fn
        {name, _, {_, nil}} ->
          quote do
            unquote({name, [], nil}) = unquote({:argv, [], nil})[unquote(name)]
          end

        {name, _, {:argv, value}} ->
          quote do
            unquote({name, [], nil}) =
              unquote({:argv, [], nil})[:__argv__] || unquote({:argv, [], nil})[unquote(name)] ||
                unquote(value)
          end

        {name, _, {_, value}} ->
          quote do
            unquote({name, [], nil}) = unquote({:argv, [], nil})[unquote(name)] || unquote(value)
          end
      end)

    {:__block__, [], get_args_ast}
  end

  defp get_parse_options(args) do
    parser_switches =
      Enum.map(args, fn
        {_, _, {:argv, _}} ->
          nil

        {name, _, {type, _}} ->
          {name, type}
      end)
      |> Enum.filter(& &1)

    parser_aliases =
      Enum.map(args, fn
        {_, nil, _} ->
          nil

        {name, alias, _} ->
          {alias, name}
      end)
      |> Enum.filter(& &1)

    [strict: parser_switches, aliases: parser_aliases]
  end

  defp get_run_deps_args(deps) do
    deps
    |> Enum.map(fn
      {name, _, [args]} -> {name, args}
      name -> {name, []}
    end)
  end

  defmacro task(name, opts \\ [], do: ast) do
    mod = __CALLER__.module
    deps = opts[:with] || []
    {name, args} = get_task_name_and_args(name)
    name = get_module_name(name, Module.get_attribute(mod, :namespace))

    get_args_ast = get_args_ast(args)
    parser_opts = get_parse_options(args)

    quote do
      defmodule unquote(name) do
        use Mix.Task
        @shortdoc Module.get_attribute(unquote(mod), :shortdoc)
        @moduledoc Module.get_attribute(unquote(mod), :taskdoc)

        def run([:internel | argv]) do
          # define args variable
          var!(argv) = argv
          _ = var!(argv)
          unquote(get_args_ast)

          # run deps
          for {dep, args} <- unquote(get_run_deps_args(deps)) do
            Mix.Task.run("#{dep}", [:internel | args])
          end

          unquote(ast)
        end

        def run(argv) do
          # parse options
          {parsed, argv, _} = OptionParser.parse(argv, unquote(parser_opts))
          run([:internel, {:__argv__, argv} | parsed])
        end
      end

      @shortdoc nil
      @taskdoc nil
    end
  end
end
