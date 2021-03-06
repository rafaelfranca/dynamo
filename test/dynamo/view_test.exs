Code.require_file "../../test_helper.exs", __FILE__

defmodule Dynamo.ViewTest do
  use ExUnit.Case

  @fixture_path File.expand_path("../../fixtures/views", __FILE__)
  @path_finder  Dynamo.View.PathFinder.new(@fixture_path)
  @view_paths   [@path_finder]

  test "renders a template" do
    body = render "hello.html"
    assert body == "HELLO!"
  end

  test "uses cached template unless it changes" do
    module = render "module.html"
    assert "Elixir-" <> _ = module

    cached = render "module.html"
    assert module == cached

    template = File.expand_path("../../fixtures/views/module.html.eex", __FILE__)

    try do
      File.touch!(template, { { 2030, 1, 1 }, { 0, 0, 0 } })
      not_cached = render "module.html"
      assert module != not_cached
    after
      File.touch!(template, :erlang.universaltime)
    end
  end

  test "uses cached template unless it is cleared" do
    module = render "module.html"
    assert "Elixir-" <> _ = module

    cached = render "module.html"
    assert module == cached

    Dynamo.View.Renderer.clear

    not_cached = render "module.html"
    assert module != not_cached
  end

  test "compiles a module with the given templates" do
    Dynamo.View.compile_module(CompileTest.CompiledViews, @path_finder.all, [:conn], prelude)

    path     = File.join(@fixture_path, "hello.html.eex")
    template = CompileTest.CompiledViews.find "hello.html"

    assert Dynamo.View.Template[identifier: ^path, key: "hello.html",
      handler: Dynamo.View.EEXHandler, format: "html", ref: { CompileTest.CompiledViews, _ }] = template

    { mod, fun } = template.ref
    assert apply(mod, fun, [[], nil]) == { [nil], "HELLO!" }
  end

  defp render(query) do
    { [nil], body } =
      Dynamo.View.render Dynamo.View.find(query, @view_paths), [conn: nil], [], prelude
    body
  end

  defp prelude do
    fn -> quote(do: use Dynamo.Helpers) end
  end
end