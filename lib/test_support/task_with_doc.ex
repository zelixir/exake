if Mix.env() == :test do
  defmodule TaskWithDoc do
    use Exake

    @shortdoc "This is a short doc"
    @taskdoc "This is a module doc"
    task :task_doc do
    end

    @shortdoc "This is another short doc"
    @taskdoc "This is another module doc"
    task :task_doc2 do
    end
  end
end
