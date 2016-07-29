print("")
print("DustIN starting...")
dofile("wifis.lua")
last=nil
function conectNET(n)
	if last == n then return end
	print(n,wifis[(n*2)+1])
	wifi.sta.config(wifis[(n*2)+1],wifis[(n*2)+2])
	last=n
end

--wifi.setmode(wifi.STATION)
wifi.setmode(wifi.STATIONAP)
counter=0;
tmr.alarm(0, 5000, 1, function()
	conectNET(counter/6)
	if wifi.sta.getip() == nil then
		print("Connecting to AP...#"..counter)
		counter=counter+1
	else
		ip, nm, gw=wifi.sta.getip()
		print("IP Address: ",ip)
		ip=nil
		nm=nil
		gw=nil
		counter=nil
		wifis=nil
		wifiscount=nil
		tmr.stop(0)
		collectgarbage()
		dofile("ReadSendDust.lua")
	end
end)
