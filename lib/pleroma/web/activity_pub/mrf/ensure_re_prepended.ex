# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.EnsureRePrepended do
  alias Pleroma.Object

  @moduledoc "Ensure a re: is prepended on replies to a post with a Subject"
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  @reply_prefix Regex.compile!("^re:[[:space:]]*", [:caseless])

  def history_awareness, do: :auto

  def filter_by_summary(
        %{data: %{"summary" => parent_summary}} = _in_reply_to,
        %{"summary" => child_summary} = child
      )
      when not is_nil(child_summary) and byte_size(child_summary) > 0 and
             not is_nil(parent_summary) and byte_size(parent_summary) > 0 do
    if (child_summary == parent_summary and not Regex.match?(@reply_prefix, child_summary)) or
         (Regex.match?(@reply_prefix, parent_summary) &&
            Regex.replace(@reply_prefix, parent_summary, "") == child_summary) do
      Map.put(child, "summary", "re: " <> child_summary)
    else
      child
    end
  end

  def filter_by_summary(_in_reply_to, child), do: child

  def filter(%{"type" => type, "object" => object} = activity)
      when type in ["Create", "Update"] and is_map(object) do
    child =
      object["inReplyTo"]
      |> Object.normalize(fetch: false)
      |> filter_by_summary(object)

    activity = Map.put(activity, "object", child)

    {:ok, activity}
  end

  def filter(activity), do: {:ok, activity}

  def describe, do: {:ok, %{}}
end
