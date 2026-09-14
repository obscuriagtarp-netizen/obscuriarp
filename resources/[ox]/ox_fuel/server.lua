local config = require 'config'

if not config then return end

if config.versionCheck then lib.versionCheck('overextended/ox_fuel') end

local ox_inventory = exports.ox_inventory

---@param vehicle number
---@param fuel number
---@param reduceOnly? boolean Don't allow fuel to be increased, unless fuel state has not been initialised.
local function setFuelState(vehicle, fuel, reduceOnly)
	if vehicle == 0 or GetEntityType(vehicle) ~= 2 then
		return
	end

	local state = Entity(vehicle).state
	fuel = math.clamp(fuel, 0, reduceOnly and state.fuel or 100)

	state:set('fuel', fuel, true)
end

---@param playerId number
---@param price number
---@return boolean?
local function defaultPaymentMethod(playerId, price)
	local money = ox_inventory:GetItemCount(playerId, 'money')
	if money >= price then return ox_inventory:RemoveItem(playerId, 'money', price) == true end

	local cashAmount = math.min(money, price)
	local creditAmount = price - cashAmount
	if creditAmount > 0 and GetResourceState('ob_bank') == 'started' then
		if cashAmount > 0 and ox_inventory:RemoveItem(playerId, 'money', cashAmount) ~= true then return end
		local transactionId = ('FUEL-%s-%s-%06d'):format(os.time(), playerId, math.random(0, 999999))
		local ok, charged = pcall(function()
			return exports.ob_bank:ChargeCredit(playerId, creditAmount, 'Posto de combustível', 'Abastecimento', transactionId)
		end)
		if ok and charged == true then return true end
		if cashAmount > 0 then ox_inventory:AddItem(playerId, 'money', cashAmount) end
	end

	TriggerClientEvent('ox_lib:notify', playerId, {
		type = 'error',
		description = 'Saldo e limite do cartão insuficientes.'
	})
end

local payMoney = defaultPaymentMethod

local function vipPrice(playerId, price)
	price = math.max(0, math.floor(tonumber(price) or 0))
	if GetResourceState('ob_vip') ~= 'started' then return price, 0, 0 end

	local ok, finalPrice, discount, percent = pcall(function()
		return exports.ob_vip:CalculateFuelDiscount(playerId, price)
	end)
	if not ok then return price, 0, 0 end
	return math.max(0, math.floor(tonumber(finalPrice) or price)),
		math.max(0, math.floor(tonumber(discount) or 0)),
		math.max(0, tonumber(percent) or 0)
end

local function notifyVipDiscount(playerId, percent, discount)
	if percent <= 0 or discount <= 0 then return end
	TriggerClientEvent('ox_lib:notify', playerId, {
		type = 'success',
		description = ('Desconto VIP de %s%% no combustivel: $%s economizados.'):format(percent, discount)
	})
end

exports('setPaymentMethod', function(fn)
	payMoney = fn or defaultPaymentMethod
end)

RegisterNetEvent('ox_fuel:pay', function(price, fuel, netid)
	local source = source
	local vehicle = NetworkGetEntityFromNetworkId(tonumber(netid) or 0)
	if vehicle == 0 or GetEntityType(vehicle) ~= 2 then return end
	if #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(vehicle)) > 10.0 then return end

	fuel = math.clamp(tonumber(fuel) or 0, 0, 100)
	local currentFuel = tonumber(Entity(vehicle).state.fuel) or 0
	local addedFuel = math.max(0, fuel - currentFuel)
	local refillValue = math.max(0.01, tonumber(config.refillValue) or 0.5)
	local ticks = math.max(0, math.ceil((addedFuel / refillValue) - 0.001))
	price = ticks * math.max(0, math.floor(tonumber(config.priceTick) or 0))
	local discount, percent
	price, discount, percent = vipPrice(source, price)
	if not payMoney(source, price) then return end

	fuel = math.floor(fuel)
	setFuelState(vehicle, fuel)

	TriggerClientEvent('ox_lib:notify', source, {
		type = 'success',
		 description = locale('fuel_success', fuel, price)
	})
	notifyVipDiscount(source, percent, discount)
end)

RegisterNetEvent('ox_fuel:fuelCan', function(hasCan, price)
	local source = source
	price = hasCan and config.petrolCan.refillPrice or config.petrolCan.price
	local discount, percent
	price, discount, percent = vipPrice(source, price)
	if hasCan then
		local item = ox_inventory:GetCurrentWeapon(source)

		if not item or item.name ~= 'WEAPON_PETROLCAN' or not payMoney(source, price) then return end

		item.metadata.durability = 100
		item.metadata.ammo = 100

		ox_inventory:SetMetadata(source, item.slot, item.metadata)

		TriggerClientEvent('ox_lib:notify', source, {
			type = 'success',
			description = locale('petrolcan_refill', price)
		})
		notifyVipDiscount(source, percent, discount)
	else
		if not ox_inventory:CanCarryItem(source, 'WEAPON_PETROLCAN', 1) then
			return TriggerClientEvent('ox_lib:notify', source, {
				type = 'error',
				description = locale('petrolcan_cannot_carry')
			})
		end

		if not payMoney(source, price) then return end

		ox_inventory:AddItem(source, 'WEAPON_PETROLCAN', 1)

		TriggerClientEvent('ox_lib:notify', source, {
			type = 'success',
			description = locale('petrolcan_buy', price)
		})
		notifyVipDiscount(source, percent, discount)
	end
end)

RegisterNetEvent('ox_fuel:updateFuelCan', function(durability, netid, fuel)
	local source = source
	local item = ox_inventory:GetCurrentWeapon(source)

	if item and durability > 0 then
		durability = math.floor(item.metadata.durability - durability)
		item.metadata.durability = durability
		item.metadata.ammo = durability

		ox_inventory:SetMetadata(source, item.slot, item.metadata)
		setFuelState(NetworkGetEntityFromNetworkId(netid), fuel)
	end

	-- player is sus?
end)

RegisterNetEvent('ox_fuel:setFuel', function(fuel)
	local playerPed = GetPlayerPed(source)
	local handle = GetVehiclePedIsIn(playerPed, false)

	setFuelState(handle, fuel, true)
end)
