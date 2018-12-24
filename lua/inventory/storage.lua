--! #textdomain "wesnoth-loti"
--
-- "Item storage" tab of the inventory dialog.
--

local _ = wesnoth.textdomain "wesnoth-loti"
local helper = wesnoth.require "lua/helper.lua"
local util = wesnoth.require "./misc.lua"

local listbox_id = "storage_listbox"
local inventory_dialog -- Set below

-- Construct tab: "item storage".
-- Note: this only creates the widget. It gets populated with data in onshow().
-- Returns: top-level [grid] widget.
local function get_tab()
	local listbox_template = wml.tag.grid {
		wml.tag.row {
			wml.tag.column {
				border = "all",
				border_size = 10,
				horizontal_grow = true,
				wml.tag.label {
					id = "storage_text",
					use_markup = "yes",
					text_alignment = "left"
				}
			}
		}
	}

	local listbox = wml.tag.listbox {
		id = listbox_id,
		wml.tag.list_definition {
			wml.tag.row {
				wml.tag.column {
					horizontal_grow = true,
					wml.tag.toggle_panel {
						listbox_template
					}
				}
			}
		}
	}

	local yesno_buttons = wml.tag.grid {
		wml.tag.row {
			wml.tag.column {
				wml.tag.button {
					id = "equip",
					label = _"Equip"
				}
			},
			wml.tag.spacer {},
			wml.tag.column {
				wml.tag.button {
					id = "close_storage",
					label = _"Close"
				}
			}
		}
	}

	return wml.tag.grid {
		-- Row 1: current item (this row is hidden if there is no current item)
		wml.tag.row {
			wml.tag.column {
				border = "all",
				border_size = 5,
				wml.tag.label {
					id = "current_item",
					use_markup = "yes"
				}
			}
		},

		-- Row 2: "Unequip" button (hidden if there is no current item)
		wml.tag.row {
			wml.tag.column {
				border = "all",
				border_size = 5,
				horizontal_alignment = "right",
				wml.tag.button {
					id = "unequip",
					label = _"Unequip"
				}
			}
		},

		-- Row 3: header of the Item Storage
		wml.tag.row {
			wml.tag.column {
				border = "top",
				border_size = 10,
				horizontal_alignment = "left",
				wml.tag.label {
					id = "storage_header"
				}
			}
		},

		-- Row 4: list of items in Item Storage
		wml.tag.row {
			wml.tag.column {
				horizontal_grow = true,
				border = "top",
				border_size = 5,
				listbox
			}
		},

		-- Row 5: "Equip" and "Close" buttons.
		wml.tag.row {
			wml.tag.column {
				horizontal_grow = true,
				border = "top",
				border_size = 10,
				yesno_buttons
			}
		}
	}
end

-- Blank tab is used in equip() to hide the Item Storage tab
-- before showing "item pick" dialog (which is semi-transparent).
function get_blank_tab()
	return wml.tag.grid {
		wml.tag.row {
			wml.tag.column {
				wml.tag.spacer { width = 10, height = 10 }
			}
		}
	}
end

local listbox_row = 0
local shown_items -- Lua array of item numbers currently displayed in listbox, e.g. { 27, 34, 56}

-- Show the menu that selects subsection of Item Storage: "sword", "spear", etc.
local function show_item_sorts()
	local sorts = loti.item.storage.list_sorts()
	for item_sort, count in pairs(sorts) do
		-- TODO: print human-readable translatable name of item_sort.
		local text = item_sort .. " (" .. count .. ")"

		listbox_row = listbox_row + 1
		wesnoth.set_dialog_value(text, listbox_id, listbox_row, "storage_text")
	end

	wesnoth.set_dialog_visible(true, listbox_id)

	-- Hide "Equip" button, not applicable
	wesnoth.set_dialog_visible(false, "equip")
end

-- Returns human-readable description text of the item (string with Pango markup)
-- and all its special properties.
-- Parameter "item" is an [object] tag.
-- Optional parameter: if count>1, it will be shown that we have more than 1 of these items.
function get_item_description(item, count)
	local text = "<span font-weight='bold'>" .. item.name .. "</span>"
	if count and count > 1 then
		text = text .. " (" .. count .. ")"
	end

	text = text .. "\n" .. item.description

	return text
end

-- Last shown item_sort, used in Equip/Unequip callbacks.
local shown_item_sort

-- Callback that updates "Item storage" tab whenever it is shown.
-- Note: see get_tab() for internal structure of this tab.
local function onshow(unit, item_sort)
	-- Clear the form. Keep the listbox hidden until populated.
	wesnoth.set_dialog_visible(false, listbox_id)
	while listbox_row > 0 do
		wesnoth.set_dialog_value("", listbox_id, listbox_row, "storage_text")
		listbox_row = listbox_row - 1
	end

	-- Hide Unequip and "Current item" until we know that something is equipped
	wesnoth.set_dialog_visible(false, "current_item")
	wesnoth.set_dialog_visible(false, "unequip")

	if not item_sort then
		return show_item_sorts()
	end

	-- Record things that will be needed in Equip/Unequip callbacks.
	shown_item_sort = item_sort
	shown_items = {}

	-- Display currently equipped item (if any)
	local item = loti.item.on_unit.find(unit, item_sort)
	if item then
		local text = _"Currently equipped: " .. get_item_description(item)
		wesnoth.set_dialog_value(text, "current_item")

		-- Show/hide fields related to current item
		wesnoth.set_dialog_visible(true, "current_item")
		wesnoth.set_dialog_visible(true, "unequip")
	end

	-- Show all stored items of the selected item_sort.
	local types = loti.item.storage.list_items(item_sort)
	for item_number, count in pairs(types) do
		listbox_row = listbox_row + 1

		local text = get_item_description(loti.item.type[item_number], count)
		wesnoth.set_dialog_value(text, listbox_id, listbox_row, "storage_text")

		-- For callback of "Equip" to know which item was selected.
		shown_items[listbox_row] = item_number
	end

	-- If the item storage is empty, hide Equip button.
	local empty = not shown_items[1]
	wesnoth.set_dialog_visible(not empty, "equip")

	if empty then
		wesnoth.set_dialog_value(_"Item storage is empty.", "storage_header")
	else
		wesnoth.set_dialog_value(_"In the item storage:", "storage_header")

		-- Unhide the listbox. Note: it's good for performance to show the listbox only
		-- when it's completely populated (i.e. here), so that
		-- it won't be unnecessarily redrawn on every set_dialog_value().
		wesnoth.set_dialog_visible(true, listbox_id)
	end
end

-- Handler for the "Unequip" button.
local function unequip()
	local unit = inventory_dialog.current_unit
	local item = loti.item.on_unit.find(unit, shown_item_sort)

	loti.item.util.take_item_from_unit(unit, item.number, item.sort)
	inventory_dialog.goto_tab("items_tab")
end

-- Handler for "Equip" button.
local function equip()
	local unit = inventory_dialog.current_unit

	-- Determine selected item in the list.
	local selected_index = wesnoth.get_dialog_value(listbox_id)
	local item_number = shown_items[selected_index]

	-- Because the "pick item" dialog (that we are about to open) is semi-transparent,
	-- make sure that "Equip" and "Close" buttons don't show through it. (confusing)
	inventory_dialog.goto_tab("blank_tab")

	-- Unstore this item. Show "pick item" dialog.
	loti.item.util.get_item_from_storage(unit, item_number, shown_item_sort)
	inventory_dialog.goto_tab("items_tab")
end

-- Add this tab to the dialog.

return function(provided_inventory_dialog)
	-- Place this interface into the file-scope local variable,
	-- because some code above needs inventory_dialog.goto_tab(), etc.
	inventory_dialog = provided_inventory_dialog

	inventory_dialog.add_tab {
		id = "storage_tab",
		grid = get_tab(),
		onshow = onshow
	}

	inventory_dialog.add_tab {
		id = "blank_tab",
		grid = get_blank_tab(),
		onshow = function() end
	}

	inventory_dialog.install_callbacks(function()
		-- Callback for Equip/Unequip buttons.
		wesnoth.set_dialog_callback(unequip, "unequip")
		wesnoth.set_dialog_callback(equip, "equip")

		-- Callback for "Close" button.
		wesnoth.set_dialog_callback(
			function() inventory_dialog.goto_tab("items_tab") end,
			"close_storage"
		)

	end)
end
