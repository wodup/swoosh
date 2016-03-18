defmodule Swoosh.Adapters.SendgridTest do
  use AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.Sendgrid

  setup_all do
    bypass = Bypass.open
    config = [base_url: "http://localhost:#{bypass.port}"]

    valid_email =
      %Swoosh.Email{}
      |> from("tony@stark.com")
      |> to("steve@rogers.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    {:ok, bypass: bypass, config: config, valid_email: valid_email}
  end

  test "successful delivery returns :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"from" => "tony@stark.com",
                      "to" => ["steve@rogers.com"],
                      "html" => "<h1>Hello</h1>",
                      "subject" => "Hello, Avengers!",
                      "text" => "Hello"}
      assert body_params == conn.body_params
      assert "/mail.send.json" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 200, "{\"message\":\"success\"}")
    end
    assert Sendgrid.deliver(email, config) == :ok
  end

  test "delivery/1 with 4xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      assert "/mail.send.json" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 401, "{\"errors\":[\"The provided authorization grant is invalid, expired, or revoked\"], \"message\":\"error\"}")
    end
    assert Sendgrid.deliver(email, config) ==
           {:error, %{"errors" => ["The provided authorization grant is invalid, expired, or revoked"], "message" => "error"}}
  end

  test "delivery/1 with 5xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      assert "/mail.send.json" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 500, "{\"errors\":[\"Internal server error\"], \"message\":\"error\"}")
    end
    assert Sendgrid.deliver(email, config) ==
           {:error, %{"errors" => ["Internal server error"], "message" => "error"}}
  end
end
