defmodule Beacon.LiveAdmin.VisualEditor.NameValueControl do
  @moduledoc false

  use Beacon.LiveAdmin.Web, :live_component
  alias Beacon.LiveAdmin.VisualEditor.Components.ControlSection
  alias Beacon.LiveAdmin.VisualEditor.NameValue
  alias Ecto.Changeset

  # Attributes that hold a media URL/path — the picker inserts the stable media path.
  @media_path_attributes ~w(src poster data-src)
  # Components whose `name` attribute selects a Media Library file by bare filename
  # (e.g. `media_image`, whose template wraps it as /<site>/__beacon_media__/<name>).
  @media_name_tags ~w(media_image)

  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.live_component module={ControlSection} id={@id <> "-section"} label="Name Value">
        <:header>
          <button :if={!@attribute.editing} type="button" phx-target={@myself} phx-click="edit">
            <.icon name="hero-pencil-square" class="w-5 h-5 text-primary" />
          </button>

          <button type="button" phx-target={@myself} phx-click="remove">
            <.icon name="hero-trash" class="w-5 h-5 text-error" />
          </button>
        </:header>

        <.form :let={f} for={@form} id={@id <> "-form"} phx-target={@myself} phx-submit="save" phx-change="validate">
          <.input
            field={f[:name]}
            placeholder="Name"
            class={"w-full mb-2 py-1 px-2 bg-base-200 border-base-300 rounded-md leading-6 text-sm #{if !@attribute.editing, do: "cursor-not-allowed"}"}
            disabled={!@attribute.editing}
          />
          <.input
            field={f[:value]}
            placeholder="Value"
            class={"w-full py-1 px-2 bg-base-200 border-base-300 rounded-md leading-6 text-sm #{if !@attribute.editing, do: "cursor-not-allowed"}"}
            disabled={!@attribute.editing}
          />

          <select
            :if={@media_mode}
            name="media_pick"
            phx-target={@myself}
            phx-change="pick_media"
            class="select select-sm select-bordered w-full mt-2 text-sm"
          >
            <option value="">Pick from Media Library…</option>
            <option
              :for={{file_name, path} <- @media_options}
              value={media_value(@media_mode, file_name, path)}
              selected={media_value(@media_mode, file_name, path) == @attribute.value}
            >
              {file_name}
            </option>
          </select>

          <div class="mt-2">
            <.button :if={@attribute.editing} phx-disable-with="Saving..." class="">Save</.button>
            <.button :if={@attribute.editing} type="button" phx-target={@myself} phx-click="discard">Discard</.button>
          </div>
        </.form>
      </.live_component>
    </div>
    """
  end

  def update(assigns, socket) do
    %{attribute: attribute} = assigns
    changeset = NameValue.changeset(%{name: attribute.name, value: attribute.value})

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:media_mode, media_picker_mode(attribute.name, assigns[:element_tag]))
     |> assign_form(changeset)}
  end

  def handle_event("validate", %{"name_value" => params}, socket) do
    changeset =
      params
      |> NameValue.changeset()
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"name_value" => params}, socket) do
    changeset =
      params
      |> NameValue.changeset()
      |> Changeset.apply_action(:update)

    case changeset do
      {:ok, name_value} ->
        %{path: path, attribute: attribute} = socket.assigns

        cond do
          name_value.name != attribute.name ->
            changes = %{updated: %{"attrs" => %{name_value.name => name_value.value}}, deleted: [attribute.name]}
            socket.assigns.on_element_change.(path, changes)

          name_value.value != attribute.value ->
            changes = %{updated: %{"attrs" => %{name_value.name => name_value.value}}}
            socket.assigns.on_element_change.(path, changes)

          # nothing has changed so we skip it to save resources
          :else ->
            :skip
        end

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("pick_media", %{"media_pick" => url}, socket) when url not in ["", nil] do
    %{path: path, attribute: attribute} = socket.assigns

    changeset =
      socket.assigns.form
      |> Changeset.put_change(:value, url)
      |> Map.put(:action, :validate)

    socket.assigns.on_element_change.(path, %{updated: %{"attrs" => %{attribute.name => url}}})

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("pick_media", _params, socket), do: {:noreply, socket}

  def handle_event("edit", _, socket) do
    send_update(socket.assigns.parent, %{edit_attribute: socket.assigns.attribute})
    {:noreply, socket}
  end

  def handle_event("remove", _, socket) do
    %{path: path, attribute: attribute} = socket.assigns
    send(self(), {:element_changed, {path, %{deleted: [attribute.name]}}})
    {:noreply, socket}
  end

  def handle_event("discard", _, socket) do
    send_update(socket.assigns.parent, %{discard_attribute: socket.assigns.attribute})
    {:noreply, socket}
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, changeset)
  end

  # nil = no picker. :path = insert the stable media path (plain <img src>, etc.).
  # :filename = insert the bare file name (media_image's `name` attribute).
  defp media_picker_mode(name, tag) do
    cond do
      name in @media_path_attributes -> :path
      name == "name" and tag in @media_name_tags -> :filename
      true -> nil
    end
  end

  defp media_value(:filename, file_name, _path), do: file_name
  defp media_value(_mode, _file_name, path), do: path
end

defmodule Beacon.LiveAdmin.VisualEditor.NameValue do
  @moduledoc false
  use Ecto.Schema
  use Phoenix.Component
  import Ecto.Changeset

  embedded_schema do
    field :name, :string
    field :value, :string
  end

  # TODO: validations
  def changeset(params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(name_value, params) do
    name_value
    |> cast(params, ~w(name value)a)
    |> validate_required([:name])
  end

  def build_form(params) do
    params
    |> changeset()
    |> to_form()
  end
end
