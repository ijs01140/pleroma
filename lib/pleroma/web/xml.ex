# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.XML do
  require Logger

  def string_from_xpath(_, :error), do: nil

  def string_from_xpath(xpath, doc) do
    try do
      {:xmlObj, :string, res} = :xmerl_xpath.string(~c"string(#{xpath})", doc)

      res =
        res
        |> to_string
        |> String.trim()

      if res == "", do: nil, else: res
    catch
      _e ->
        Logger.debug("Couldn't find xpath #{xpath} in XML doc")
        nil
    end
  end

  def parse_document(text) do
    try do
      {doc, _rest} =
        text
        |> :binary.bin_to_list()
        |> :xmerl_scan.string(
          quiet: true,
          allow_entities: false
        )

      {:ok, doc}
    rescue
      _e ->
        Logger.debug("Couldn't parse XML: #{inspect(text)}")
        :error
    catch
      :exit, _error ->
        Logger.debug("Couldn't parse XML: #{inspect(text)}")
        :error
    end
  end
end
