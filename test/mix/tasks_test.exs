Code.require_file "../../test_helper.exs", __FILE__

defmodule Mix.TasksTest do
  use ExUnit.Case
  import MixHelpers

  test "compiles an application" do
    in_tmp "my_compiled_app", fn ->
      app_with_dynamo_deps_path

      # Cannot boot production without compiling
      output = System.cmd "MIX_ENV=prod mix server"
      assert output =~ %r(could not find endpoint ApplicationRouter, please ensure it was compiled)

      output = System.cmd "MIX_ENV=prod mix compile"
      assert output =~ %r(Compiled app/routers/application_router.ex)
      assert output =~ %r(Compiled config/app.ex)
      assert output =~ %r(Generated my_compiled_app.app)

      # Views are also compiled
      assert output =~ %r(Generated MyCompiledApp.CompiledViews)
      assert File.regular?("ebin/Elixir-MyCompiledApp-CompiledViews.beam")

      # Can recompile after changes
      File.touch!("app/routers/application_router.ex", { { 2030, 1, 1 }, { 0, 0, 0 } })
      output = System.cmd "MIX_ENV=prod mix compile"
      assert output =~ %r(Compiled app/routers/application_router.ex)

      # Cannot boot development after compiling
      output = System.cmd "MIX_ENV=dev mix compile"
      assert output =~ %r(the dynamo application MyCompiledApp was compiled and locked for environment)

      # Unless we clean it
      output = System.cmd "MIX_ENV=dev mix do clean, compile"
      assert output =~ %r(Generated my_compiled_app.app)
    end
  end

  test "prints application filters" do
    in_tmp "my_filters_app", fn ->
      app_with_dynamo_deps_path

      output = System.cmd "mix dynamo.filters"
      assert output =~ %r(filter Dynamo.Filters.Head)
      assert output =~ %r(filter \{Dynamo.Filters.Reloader,true,true\})
      assert output =~ %r(ApplicationRouter.service/1)

      # Check it works with first compilation in prod
      output = System.cmd "MIX_ENV=prod mix do compile, dynamo.filters"
      refute output =~ %r(Dynamo.Filters.Reloader)
      assert output =~ %r(ApplicationRouter.service/1)

      # Check that noop compile also works
      output = System.cmd "MIX_ENV=prod mix do compile, dynamo.filters"
      refute output =~ %r(Dynamo.Filters.Reloader)
      assert output =~ %r(ApplicationRouter.service/1)
    end
  end

  test "runs application code" do
    in_tmp "my_run_app", fn ->
      app_with_dynamo_deps_path

      output = System.cmd %b{mix run "Dynamo.app.start; IO.inspect HelloRouter.__info__(:self)"}
      assert output =~ %r(HelloRouter)

      output = System.cmd %b{MIX_ENV=prod mix do compile, run "Dynamo.app.start; IO.inspect HelloRouter.__info__(:self)"}
      assert output =~ %r(HelloRouter)
    end
  end

  test "tests application code" do
    in_tmp "my_test_app", fn ->
      app_with_dynamo_deps_path

      File.write! "test/routers/hello_router_test.exs", """
      Code.require_file "../../test_helper.exs", __FILE__

      defmodule HelloRouterTest do
        use ExUnit.Case

        test "hello router is autoloaded" do
          assert HelloRouter.__info__(:self)
        end
      end
      """

      output = System.cmd %b{mix test}
      assert output =~ %r(3 tests, 0 failures)
    end
  end

  test "warns on missing dependencies" do
    in_tmp "missing_deps", fn ->
      Mix.Tasks.Dynamo.run [".", "--dev"]
      error = %r(Some dependencies are out of date)

      output = System.cmd "mix server"
      assert output =~ error

      output = System.cmd "MIX_ENV=prod mix server"
      assert output =~ error
    end
  end

  defp app_with_dynamo_deps_path do
    Mix.Tasks.Dynamo.run [".", "--dev"]
    File.cp! "../../mix.lock", "mix.lock"

    File.write! "mix.exs",
      Regex.replace(%r"deps: deps", File.read!("mix.exs"), %b(deps: deps, deps_path: "../../deps"))

    File.write! "app/routers/hello_router.ex", """
    defmodule HelloRouter do
      use Dynamo.Router
    end
    """
  end
end