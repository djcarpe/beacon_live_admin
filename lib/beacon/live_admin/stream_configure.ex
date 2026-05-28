defmodule Beacon.LiveAdmin.StreamConfigure do
  @moduledoc false

  # Guarded `Phoenix.LiveView.stream_configure/3` wrapper.
  #
  # Beacon.LiveAdmin.PageLive uses a non-standard pattern where the
  # feature LiveViews' (`ComponentEditorLive.Index`, `MediaLibraryLive.Index`,
  # etc.) `mount/3` callbacks are called again on every `live_patch`
  # between admin pages — not only on the initial channel mount.
  #
  # `Phoenix.LiveView.stream_configure/3` raises if the stream has
  # already been configured OR streamed, so unconditional calls in
  # those mount/3 implementations crash the LV when the user navigates
  # back to a page they've already streamed.
  #
  # This helper makes the call idempotent — if the stream is already
  # configured or already streamed, the socket is returned unchanged.

  import Phoenix.LiveView, only: [stream_configure: 3]

  alias Phoenix.LiveView.LiveStream
  alias Phoenix.LiveView.Socket

  @spec maybe_configure(Socket.t(), atom() | String.t(), keyword()) :: Socket.t()
  def maybe_configure(%Socket{} = socket, name, opts) do
    streams = Map.get(socket.assigns, :streams) || %{}
    configured = Map.get(streams, :__configured__) || %{}

    cond do
      match?(%LiveStream{}, Map.get(streams, name)) -> socket
      Map.has_key?(configured, name) -> socket
      true -> stream_configure(socket, name, opts)
    end
  end
end
