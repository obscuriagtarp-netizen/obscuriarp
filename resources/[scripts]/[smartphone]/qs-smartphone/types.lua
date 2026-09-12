---@class ServerFramework
---@field getPlayerFromId fun(self: ServerFramework, source: number): table
---@field getIdentifier fun(self: ServerFramework, source: number): string
---@field getAccountMoney fun(self: ServerFramework, source: number, account: MoneyType): number
---@field removeAccountMoney fun(self: ServerFramework, source: number, account: MoneyType, amount: number): boolean
---@field addAccountMoney fun(self: ServerFramework, source: number, account: MoneyType, amount: number)
---@field removeItem fun(self: ServerFramework, source: number, item: string, count: number): boolean
---@field playerIsAdmin fun(self: ServerFramework, source: number): boolean
---@field getUserName fun(self: ServerFramework, source: number): string, string
---@field registerUsableItem fun(self: ServerFramework, item: string, cb: function)
---@field getSourceFromIdentifier fun(self: ServerFramework, identifier: string): number
---@field getItem fun(self: ServerFramework, source: number, item: string): {count: number}
---@field addItem fun(self: ServerFramework, source: number, item: string, count: number, slot?: number | false, info?: table): boolean
---@field getUserNameFromIdentifier fun(self: ServerFramework, identifier: string): string
---@field getJobName fun(self: ServerFramework, source: number): string
---@field getJobGrade fun(self: ServerFramework, source: number): number
---@field getPlayers fun(self: ServerFramework): table
---@field getInventory fun(self: ServerFramework, source: number): table
---@field getItemList fun(self: ServerFramework): table
---@field getJobsData fun(self: ServerFramework): Job[]
---@field searchPlayers fun(self: ServerFramework, query: string): table
---@field getMeta fun(self: ServerFramework, source: number): table
---@field setJob fun(self: ServerFramework, source: number, job: string, grade: number): boolean
---@field garageTable string
---@field garageIdentifierColumn string
---@field setPhoneNumber fun(self: ServerFramework, source: number, phoneNumber: string)

---@class ClientFramework
---@field getPlayerData fun(self: ClientFramework): table
---@field getIdentifier fun(self: ClientFramework): string
---@field getJobName fun(self: ClientFramework): string
---@field getJobGrade fun(self: ClientFramework): number
---@field getPlayers fun(self: ClientFramework): table
---@field getObject fun(self: ClientFramework): table

---@class Job
---@field name string
---@field label string
---@field grades {label: string, grade: number}

---@class Gang
---@field name string
---@field label string
---@field grades {label: string, grade: number}

---@alias MoneyType 'money' | 'bank' | 'black_money'

---@class PhoneItem
---@field slot number          Inventory slot
---@field name string          Item name
---@field metadata table|nil   Item metadata (if supported)

---@class InventoryAdapterInterface
---@field getPhoneItem fun(source: number): PhoneItem|nil
---@field setMetadata fun(source: number, slot: number, data: table)
---@field registerUsable fun(itemName: string, callback: fun(source: number, item: PhoneItem))
---@field supportsMetadata fun(): boolean
---@field getItems fun(source: number): table
