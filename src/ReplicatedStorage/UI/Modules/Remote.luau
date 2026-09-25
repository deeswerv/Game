--!strict
-- A remote the interface can hold before the server has made it.
--
-- MainUI used to fetch every remote with a bare WaitForChild while it was building the menus.
-- That waits forever if the service that creates the remote failed to load -- and one did:
-- MonetizationService died on a DataStore call in a place opened from a file, PromptPurchase
-- never appeared, and MainUI stopped dead half way through. Everything after that line --
-- the shop, the dock, every menu hotkey, the "+" beside the cash -- simply never existed.
--
-- A Lazy stands in for the remote instead. Building the menus never waits on it; the remote
-- is looked up the first time it is actually used (with a timeout, so a missing one costs a
-- few seconds on one click rather than the whole interface), and a listener attaches as soon
-- as the remote turns up, however late.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remote = {}

-- How long a call waits for a remote that is not there yet before giving up.
local CALL_WAIT = 8
-- Listeners wait as long as it takes; this is only a cap so WaitForChild never warns.
local LISTEN_WAIT = 1e6

export type Connection = { Disconnect: (self: Connection) -> () }
export type Lazy = {
	InvokeServer: (self: Lazy, ...any) -> ...any,
	FireServer: (self: Lazy, ...any) -> (),
	OnClientEvent: { Connect: (self: any, fn: (...any) -> ()) -> Connection },
	Get: (self: Lazy, timeout: number?) -> Instance?,
}

--- `folder` is the ReplicatedStorage folder the server makes the remote in ("GameRemotes",
--- "Remotes"); `name` is the remote's name.
function Remote.get(folder: string, name: string): Lazy
	local resolved: Instance? = nil
	local warned = false

	local function find(timeout: number): Instance?
		if resolved and resolved.Parent then
			return resolved
		end
		local container = ReplicatedStorage:WaitForChild(folder, timeout)
		local found = container and container:WaitForChild(name, timeout)
		if found then
			resolved = found
		elseif not warned then
			warned = true
			warn(("[UI] %s.%s is missing -- is the server service that makes it failing to start?"):format(folder, name))
		end
		return found
	end

	local lazy = {} :: any

	function lazy:Get(timeout: number?): Instance?
		return find(timeout or CALL_WAIT)
	end

	function lazy:InvokeServer(...: any): ...any
		local remote = find(CALL_WAIT)
		if remote and remote:IsA("RemoteFunction") then
			return remote:InvokeServer(...)
		end
		return nil
	end

	function lazy:FireServer(...: any)
		local remote = find(CALL_WAIT)
		if remote and remote:IsA("RemoteEvent") then
			remote:FireServer(...)
		end
	end

	lazy.OnClientEvent = {
		Connect = function(_self: any, fn: (...any) -> ()): Connection
			local alive = true
			local connection: RBXScriptConnection? = nil
			task.spawn(function()
				local remote = find(LISTEN_WAIT)
				if alive and remote and remote:IsA("RemoteEvent") then
					connection = remote.OnClientEvent:Connect(fn)
				end
			end)
			local handle = {} :: any
			function handle:Disconnect()
				alive = false
				if connection then
					connection:Disconnect()
				end
			end
			return handle
		end,
	}

	return lazy :: Lazy
end

return Remote
