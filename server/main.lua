local function CheckVersion()
    PerformHttpRequest("https://raw.githubusercontent.com/lone17k/script_updates/refs/heads/main/olisound", function(err, text, headers)
        local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version', 0)
        
        if not text then 
            print("^1[olisound] Unable to check for updates.^7")
            return 
        end
        
        local data = json.decode(text)
        if not data or not data.version then
            print("^1[olisound] Invalid update data received.^7")
            return
        end

        if data.version ~= currentVersion then
            print("^3-------------------------------------------------------------------------^7")
            print("^1[olisound] Update Available!^7")
            print("^3Current Version: ^1" .. currentVersion .. "^7")
            print("^3New Version: ^2" .. data.version .. "^7")
            if data.updates and #data.updates > 0 then
                print("^3Changelog:^7")
                for i=1, #data.updates do
                    print("^7- " .. data.updates[i] .. "^7")
                end
            end
            print("^3Please update the script from your keymaster or github.^7")
            print("^3-------------------------------------------------------------------------^7")
        else
            print("^2[olisound] Script is up to date! (Version: " .. currentVersion .. ")^7")
        end
    end, "GET", "", "")
end

CreateThread(function()
    CheckVersion()
end)
