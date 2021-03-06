defmodule Dynamo.Router.Rendering do
  @moduledoc """
  Module responsible for template rendering
  and similar functions.
  """

  @doc false
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
    end
  end

  @doc """
  Renders a template and assigns its contents to
  the connection response body and content type.
  If the connection is in streaming mode, the template
  is streamed after it is rendered as a whole chunk.

  Besides the connection and the template name,
  this function also receives extra assigns as
  arguments. Assigns are used by the application
  developer to pass information from the router
  to the view.

  It raises `Dynamo.View.TemplateNotFound` if the given
  template can't be found.

  ## Examples

      # Renders the template usually at app/views/hello.html
      render conn, "hello.html"

      # Assign to data (accessible as @data in the template)
      conn = conn.assign(:data, "Sample")
      render conn, "hello.html"

      # Same as before, but does not assign to the connection
      render conn, "hello.html", data: "Sample"

  ## Layouts

  Rendering also supports layouts. The layout name should
  be given as an assign. It is common to set a layout that
  is used throughout the application in your `ApplicationRouter`
  and it will be carried out to all other routers:

      prepare do
        conn.assign :layout, "application.html"
      end

  """
  def render(conn, template, assigns // []) do
    app        = conn.app
    view_paths = app.view_paths
    prelude    = fn -> app.views end
    template   = Dynamo.View.find!(template, view_paths)

    if template.format && !conn.resp_content_type do
      mime = :mimetypes.ext_to_mimes(template.format)
      conn = conn.resp_content_type(hd(mime))
    end

    assigns = Keyword.merge(conn.assigns, assigns)
    layout  = assigns[:layout]
    { [conn], body } = Dynamo.View.render(template, [conn: conn], assigns, prelude)

    if layout do
      template = Dynamo.View.find!("layouts/" <> layout, view_paths)
      conn     = Dynamo.Helpers.ContentFor.put_content(conn, :template, body)
      { [conn], body } = Dynamo.View.render(template, [conn: conn], assigns, prelude)
    end

    conn.resp_body(body)
  end
end