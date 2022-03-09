local tools = require('addons/tools')

local p_stats = require('production-score')

local markets = {}

markets.upgrade_offers = {
    {
        price = {{"coin", 100}},
        offer = {type = "gun-speed", ammo_category = "bullet", modifier = 0.25}
    }, {
        price = {{"coin", 100}},
        offer = {
            type = "gun-speed",
            ammo_category = "shotgun-shell",
            modifier = 0.25
        }
    }, {
        price = {{"coin", 100}},
        offer = {
            type = "gun-speed",
            ammo_category = "landmine",
            modifier = 0.25
        }
    }, {
        price = {{"coin", 100}},
        offer = {type = "gun-speed", ammo_category = "grenade", modifier = 0.25}
    }, {
        price = {{"coin", 250}},
        offer = {
            type = "gun-speed",
            ammo_category = "cannon-shell",
            modifier = 0.25
        }
    }, {
        price = {{"coin", 250}},
        offer = {
            type = "gun-speed",
            ammo_category = "flamethrower",
            modifier = 0.25
        }
    }, {
        price = {{"coin", 500}},
        offer = {type = "gun-speed", ammo_category = "rocket", modifier = 0.25}
    }, {
        price = {{"coin", 1000}},
        offer = {type = "gun-speed", ammo_category = "laser", modifier = 0.25}
    }, {
        price = {{"coin", 200}},
        offer = {
            type = "ammo-damage",
            ammo_category = "bullet",
            modifier = 0.25
        }
    }, {
        price = {{"coin", 200}},
        offer = {
            type = "ammo-damage",
            ammo_category = "shotgun-shell",
            modifier = 0.25
        }
    }, {
        price = {{"coin", 200}},
        offer = {
            type = "ammo-damage",
            ammo_category = "landmine",
            modifier = 0.25
        }
    }, {
        price = {{"coin", 200}},
        offer = {
            type = "ammo-damage",
            ammo_category = "grenade",
            modifier = 0.25
        }
    }, {
        price = {{"coin", 250}},
        offer = {
            type = "ammo-damage",
            ammo_category = "cannon-shell",
            modifier = 0.25
        }
    }, {
        price = {{"coin", 250}},
        offer = {
            type = "ammo-damage",
            ammo_category = "flamethrower",
            modifier = 0.25
        }
    }, {
        price = {{"coin", 500}},
        offer = {
            type = "ammo-damage",
            ammo_category = "rocket",
            modifier = 0.25
        }
    }, {
        price = {{"coin", 1000}},
        offer = {type = "ammo-damage", ammo_category = "laser", modifier = 0.25}
    }, {
        price = {{"coin", 500}},
        offer = {
            type = "turret-attack",
            turret_id = "gun-turret",
            modifier = 0.25
        }
    }, {
        price = {{"coin", 3000}},
        offer = {
            type = "turret-attack",
            turret_id = "flamethrower-turret",
            modifier = 0.25
        }
    }, {
        price = {{"coin", 5000}},
        offer = {
            type = "turret-attack",
            turret_id = "laser-turret",
            modifier = 0.25
        }
    }, {
        price = {{"coin", 100}},
        offer = {type = "character-health-bonus", modifier = 10}
    }
}

function markets.getPrices()
    markets.buy_offers = {}
    markets.sell_offers = {}
    return p_stats.generate_price_list()
end

function markets.formatPrices()
    for name, value in pairs(markets.item_values) do
        if game.item_prototypes[name] then
            if value < 65535 then
                markets.buy_offers[name] = {
                    price = {{"coin", value}},
                    offer = {type = "give-item", item = name, count = 1}
                }
                markets.sell_offers[name] = tools.round(value * 0.75)
            elseif value > 65535 then
                local its = math.floor(value / 65535)
                markets.buy_offers[name] = {
                    price = {},
                    offer = {type = "give-item", item = name, count = 1}
                }
                for i = 1, its, 1 do
                    table.insert(markets.buy_offers[name].price, {"coin", 65535})
                end
                table.insert(markets.buy_offers[name].price,
                             {"coin", (value % 65535)})
            end
        end
    end
end

function markets.init()
    markets.item_values = tools.sortByValue(markets.getPrices())
    game.write_file("market/item_values.lua", serpent.block(markets.item_values))
    markets.formatPrices()
    global.ocore.market_chest = {}
end

function markets.create(player, position)
    local player = player
    local position = position
    local market = game.surfaces[GAME_SURFACE_NAME].create_entity {
        name = "market",
        position = position,
        force = "neutral"
    }
    local chest = game.surfaces[GAME_SURFACE_NAME].create_entity {
        name = "steel-chest",
        position = {x = position.x + 6, y = position.y},
        force = "neutral"
    }
    tools.protect_entity(market)
    tools.protect_entity(chest)
    global.ocore.market_chest[player.name] = chest

    TemporaryHelperText(
        "The market allows you to buy items and upgrades for coin.",
        {market.position.x, market.position.y + 1.5}, TICKS_PER_MINUTE * 2,
        {r = 1, g = 0, b = 1})
    TemporaryHelperText("Dump items to chest to sell for coin.",
                        {chest.position.x + 1.5, chest.position.y - 0.5},
                        TICKS_PER_MINUTE * 2, {r = 1, g = 0, b = 1})

    for __, item in pairs(markets.upgrade_offers) do
        market.add_market_item(item)
    end
    for __, item in pairs(markets.buy_offers) do market.add_market_item(item) end
    return market
end

function markets.on_tick()
    if game.tick % 60 == 0 then
        for player_name, chest in pairs(global.ocore.market_chest) do
            local chest_inv = chest.get_inventory(defines.inventory.chest)
            if (chest_inv == nil) then return end
            if (chest_inv.is_empty()) then return end

            local contents = chest_inv.get_contents()
            local t = {}
            for name, count in pairs(contents) do
                if markets.sell_offers[name] then
                    table.insert(t, name)
                end
                if #t > 0 then break end
            end
            local item_name = t[1]
            if item_name then
                if chest_inv.can_insert {
                    name = "coin",
                    count = markets.sell_offers[item_name]
                } then
                    chest_inv.insert {
                        name = "coin",
                        count = markets.sell_offers[item_name]
                    }
                    chest_inv.remove({name = item_name, count = 1})
                end
            end
        end
    end
end

return markets
