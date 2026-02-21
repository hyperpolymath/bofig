# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.CoreComponents do
  @moduledoc """
  Core UI components for the Evidence Graph web interface.

  Provides standard Phoenix components (flash, button, header, table)
  plus domain-specific components for the PROMPT framework and
  evidence graph visualisation.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  use Gettext, backend: EvidenceGraphWeb.Gettext

  # ---------------------------------------------------------------------------
  # Flash messages
  # ---------------------------------------------------------------------------

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome!</.flash>
  """
  attr :id, :string, default: nil
  attr :flash, :map, default: %{}, doc: "the map of flash messages"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1",
        @kind == :info && "bg-emerald-50 text-emerald-800 ring-emerald-500 fill-cyan-900",
        @kind == :error && "bg-rose-50 text-rose-900 ring-rose-500 fill-rose-900"
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <span class="hero-information-circle-mini" :if={@kind == :info} />
        <span class="hero-exclamation-circle-mini" :if={@kind == :error} />
        {@title}
      </p>
      <p class="mt-2 text-sm leading-5">{msg}</p>
      <button type="button" class="group absolute top-1 right-1 p-2" aria-label={gettext("close")}>
        <span class="hero-x-mark-solid h-5 w-5 opacity-40 group-hover:opacity-70" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard flash auto-show behaviour.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash kind={:info} title={gettext("Success!")} flash={@flash} />
      <.flash kind={:error} title={gettext("Error!")} flash={@flash} />
      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error")}
        phx-connected={hide("#client-error")}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <span class="hero-arrow-path-solid h-3 w-3 ml-1 animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error")}
        phx-connected={hide("#server-error")}
        hidden
      >
        {gettext("Hang in there while we get back on track")}
        <span class="hero-arrow-path-solid h-3 w-3 ml-1 animate-spin" />
      </.flash>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Standard components
  # ---------------------------------------------------------------------------

  @doc """
  Renders a header with title.
  """
  attr :class, :string, default: nil

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", @class]}>
      <div>
        <h1 class="text-lg font-semibold leading-8 text-zinc-800 dark:text-zinc-200">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="mt-2 text-sm leading-6 text-zinc-600 dark:text-zinc-400">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div :if={@actions != []} class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Send</.button>
      <.button phx-click="go" class="ml-2">Send</.button>
  """
  attr :type, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "phx-submit-loading:opacity-75 rounded-lg bg-zinc-900 hover:bg-zinc-700 py-2 px-3",
        "text-sm font-semibold leading-6 text-white active:text-white/80",
        "dark:bg-zinc-100 dark:hover:bg-zinc-300 dark:text-zinc-900",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders a simple data table.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="Name">{user.name}</:col>
        <:col :let={user} label="Email">{user.email}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-y-auto px-4 sm:overflow-visible sm:px-0">
      <table class="w-[40rem] mt-11 sm:w-full">
        <thead class="text-sm text-left leading-6 text-zinc-500 dark:text-zinc-400">
          <tr>
            <th :for={col <- @col} class="p-0 pb-4 pr-6 font-normal">{col[:label]}</th>
            <th :if={@action != []} class="relative p-0 pb-4">
              <span class="sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
          class="relative divide-y divide-zinc-100 dark:divide-zinc-800 border-t border-zinc-200 dark:border-zinc-700 text-sm leading-6 text-zinc-700 dark:text-zinc-300"
        >
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)} class="group hover:bg-zinc-50 dark:hover:bg-zinc-900/50">
            <td
              :for={{col, i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={["relative p-0", @row_click && "hover:cursor-pointer"]}
            >
              <div class="block py-4 pr-6">
                <span class="absolute -inset-y-px right-0 -left-4 group-hover:bg-zinc-50 dark:group-hover:bg-zinc-900/50 sm:rounded-l-xl" />
                <span class={["relative", i == 0 && "font-semibold text-zinc-900 dark:text-zinc-100"]}>
                  {render_slot(col, @row_item.(row))}
                </span>
              </div>
            </td>
            <td :if={@action != []} class="relative w-14 p-0">
              <div class="relative whitespace-nowrap py-4 text-right text-sm font-medium">
                <span class="absolute -inset-y-px -right-4 left-0 group-hover:bg-zinc-50 dark:group-hover:bg-zinc-900/50 sm:rounded-r-xl" />
                <span
                  :for={action <- @action}
                  class="relative ml-4 font-semibold leading-6 text-zinc-900 dark:text-zinc-100 hover:text-zinc-700 dark:hover:text-zinc-300"
                >
                  {render_slot(action, @row_item.(row))}
                </span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a back navigation link.

  ## Examples

      <.back navigate={~p"/investigations"}>Back to investigations</.back>
  """
  attr :navigate, :any, required: true
  slot :inner_block, required: true

  def back(assigns) do
    ~H"""
    <div class="mt-16">
      <.link navigate={@navigate} class="text-sm font-semibold leading-6 text-zinc-900 dark:text-zinc-100 hover:text-zinc-700 dark:hover:text-zinc-300">
        <span class="hero-arrow-left-solid h-3 w-3" />
        {render_slot(@inner_block)}
      </.link>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Icon component
  # ---------------------------------------------------------------------------

  @doc """
  Renders a hero icon by name.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-information-circle" class="size-6" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  # ---------------------------------------------------------------------------
  # Form components
  # ---------------------------------------------------------------------------

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
               range radio search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <label class="flex items-center gap-4 text-sm leading-6 text-zinc-600 dark:text-zinc-400">
      <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
      <input
        type="checkbox"
        id={@id}
        name={@name}
        value="true"
        checked={@checked}
        class="rounded border-zinc-300 text-zinc-900 focus:ring-0 dark:border-zinc-600 dark:bg-zinc-800"
        {@rest}
      />
      {@label}
    </label>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div>
      <.label for={@id}>{@label}</.label>
      <select
        id={@id}
        name={@name}
        class="mt-2 block w-full rounded-md border border-gray-300 bg-white shadow-sm focus:border-zinc-400 focus:ring-0 sm:text-sm dark:border-zinc-600 dark:bg-zinc-800 dark:text-zinc-100"
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div>
      <.label for={@id}>{@label}</.label>
      <textarea
        id={@id}
        name={@name}
        class={[
          "mt-2 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6 dark:bg-zinc-800 dark:text-zinc-100",
          "min-h-[6rem] phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400",
          @errors == [] && "border-zinc-300 focus:border-zinc-400 dark:border-zinc-600",
          @errors != [] && "border-rose-400 focus:border-rose-400"
        ]}
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div>
      <.label for={@id}>{@label}</.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "mt-2 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6 dark:bg-zinc-800 dark:text-zinc-100",
          "phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400",
          @errors == [] && "border-zinc-300 focus:border-zinc-400 dark:border-zinc-600",
          @errors != [] && "border-rose-400 focus:border-rose-400"
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-semibold leading-6 text-zinc-800 dark:text-zinc-200">
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-3 flex gap-3 text-sm leading-6 text-rose-600 dark:text-rose-400">
      <span class="hero-exclamation-circle-mini mt-0.5 h-5 w-5 flex-none" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(EvidenceGraphWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(EvidenceGraphWeb.Gettext, "errors", msg, opts)
    end
  end

  # ---------------------------------------------------------------------------
  # Evidence Graph domain components
  # ---------------------------------------------------------------------------

  @doc """
  Renders a PROMPT score badge with colour-coded severity.

  ## Examples

      <.prompt_badge dimension="provenance" score={85} />
  """
  attr :dimension, :string, required: true
  attr :score, :integer, required: true
  attr :class, :string, default: nil

  def prompt_badge(assigns) do
    ~H"""
    <span class={[
      "prompt-badge",
      cond do
        @score >= 70 -> "high"
        @score >= 40 -> "medium"
        true -> "low"
      end,
      @class
    ]}>
      <span class="capitalize">{@dimension}</span>
      <span class="ml-1 font-bold">{@score}</span>
    </span>
    """
  end

  @doc """
  Renders an audience type badge with appropriate colour.

  ## Examples

      <.audience_badge type={:researcher} />
      <.audience_badge type={:policymaker} active />
  """
  attr :type, :atom, required: true
  attr :active, :boolean, default: false
  attr :rest, :global, include: ~w(phx-click phx-value-audience)

  def audience_badge(assigns) do
    ~H"""
    <span class={[
      "audience-badge",
      to_string(@type),
      @active && "ring-2 ring-offset-1 font-bold"
    ]} {@rest}>
      <span class="capitalize">{audience_label(@type)}</span>
    </span>
    """
  end

  defp audience_label(:affected_person), do: "Affected Person"
  defp audience_label(type), do: type |> to_string() |> String.capitalize()

  @doc """
  Renders a claim card with PROMPT scores.

  ## Examples

      <.claim_card claim={@claim} />
  """
  attr :claim, :map, required: true
  attr :show_scores, :boolean, default: true
  attr :class, :string, default: nil

  def claim_card(assigns) do
    ~H"""
    <div class={[
      "rounded-lg border border-claim-200 bg-claim-50 dark:bg-claim-950 dark:border-claim-800 p-4",
      @class
    ]}>
      <div class="flex items-start justify-between gap-2">
        <div class="flex-1">
          <div class="flex items-center gap-2 mb-2">
            <span class="inline-flex items-center rounded-md bg-claim-100 px-2 py-1 text-xs font-medium text-claim-700 dark:bg-claim-900 dark:text-claim-300">
              {claim_type_label(@claim.claim_type)}
            </span>
            <span :if={@claim.confidence_level} class="text-xs text-gray-500">
              {Float.round(@claim.confidence_level * 100, 0)}% confidence
            </span>
          </div>
          <p class="text-sm text-gray-900 dark:text-gray-100">{@claim.text}</p>
        </div>
      </div>
      <div :if={@show_scores && @claim.prompt_scores} class="mt-3 flex flex-wrap gap-1">
        <.prompt_badge dimension="P" score={@claim.prompt_scores.provenance} />
        <.prompt_badge dimension="R" score={@claim.prompt_scores.replicability} />
        <.prompt_badge dimension="O" score={@claim.prompt_scores.objective} />
        <.prompt_badge dimension="M" score={@claim.prompt_scores.methodology} />
        <.prompt_badge dimension="P" score={@claim.prompt_scores.publication} />
        <.prompt_badge dimension="T" score={@claim.prompt_scores.transparency} />
      </div>
    </div>
    """
  end

  defp claim_type_label(:primary), do: "Primary"
  defp claim_type_label(:supporting), do: "Supporting"
  defp claim_type_label(:counter), do: "Counter"
  defp claim_type_label(_), do: "Claim"

  @doc """
  Renders an evidence card with metadata and PROMPT scores.

  ## Examples

      <.evidence_card evidence={@evidence} />
  """
  attr :evidence, :map, required: true
  attr :show_scores, :boolean, default: true
  attr :class, :string, default: nil

  def evidence_card(assigns) do
    ~H"""
    <div class={[
      "rounded-lg border border-evidence-200 bg-evidence-50 dark:bg-evidence-950 dark:border-evidence-800 p-4",
      @class
    ]}>
      <div class="flex items-start justify-between gap-2">
        <div class="flex-1">
          <div class="flex items-center gap-2 mb-2">
            <span class="inline-flex items-center rounded-md bg-evidence-100 px-2 py-1 text-xs font-medium text-evidence-700 dark:bg-evidence-900 dark:text-evidence-300">
              {evidence_type_label(@evidence.evidence_type)}
            </span>
          </div>
          <h3 class="text-sm font-medium text-gray-900 dark:text-gray-100">{@evidence.title}</h3>
          <p :if={@evidence.source_url} class="mt-1 text-xs text-blue-600 dark:text-blue-400 truncate">
            <a href={@evidence.source_url} target="_blank" rel="noopener noreferrer">
              {@evidence.source_url}
            </a>
          </p>
        </div>
      </div>
      <div :if={@show_scores && @evidence.prompt_scores} class="mt-3 flex flex-wrap gap-1">
        <.prompt_badge dimension="P" score={@evidence.prompt_scores.provenance} />
        <.prompt_badge dimension="R" score={@evidence.prompt_scores.replicability} />
        <.prompt_badge dimension="O" score={@evidence.prompt_scores.objective} />
        <.prompt_badge dimension="M" score={@evidence.prompt_scores.methodology} />
        <.prompt_badge dimension="P" score={@evidence.prompt_scores.publication} />
        <.prompt_badge dimension="T" score={@evidence.prompt_scores.transparency} />
      </div>
    </div>
    """
  end

  defp evidence_type_label(:document), do: "Document"
  defp evidence_type_label(:dataset), do: "Dataset"
  defp evidence_type_label(:interview), do: "Interview"
  defp evidence_type_label(:media), do: "Media"
  defp evidence_type_label(_), do: "Other"

  @doc """
  Renders a relationship indicator showing the type and weight of a connection.

  ## Examples

      <.relationship_indicator type={:supports} weight={0.8} confidence={0.9} />
  """
  attr :type, :atom, required: true
  attr :weight, :float, default: nil
  attr :confidence, :float, default: nil
  attr :class, :string, default: nil

  def relationship_indicator(assigns) do
    ~H"""
    <div class={["inline-flex items-center gap-1 text-xs", @class]}>
      <span class={[
        "w-2 h-2 rounded-full",
        @type == :supports && "bg-supports",
        @type == :contradicts && "bg-contradicts",
        @type == :contextualizes && "bg-contextualizes"
      ]} />
      <span class="capitalize text-gray-600 dark:text-gray-400">{@type}</span>
      <span :if={@weight} class="text-gray-400">
        ({Float.round(@weight * 100, 0)}%)
      </span>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # JS commands
  # ---------------------------------------------------------------------------

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end
end
