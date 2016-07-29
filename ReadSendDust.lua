
dofile("formulas.lua")
dofile("config.lua")
-- for blinking LED
gpio.mode(5,gpio.OUTPUT) 
gpio.mode(6,gpio.OUTPUT) 
gpio.mode(7,gpio.OUTPUT) 

--czasstart = tmr.now()


function readWIFI()	
		wifi.sta.getap(function(t) 
			if t then 
				for k,v in pairs(t) do 
					tmr.wdclr()
					l = string.format("%-10s",k) 
					if k=="znakzorro" then 
						paramWIFI = string.match(v,"-%w+")
						paramHEAP = node.heap()
						k=nil
						v=nil
						l=nil
						t=nil
						return
					end
				end
			end
		end)
end

print ("Dust_IN action ...")
--GLOBALS for app
paramWIFI = -70
paramHEAP = 0
WatchDogCounter = 0;
dust25 = 0
dust10 = 0
countDust25 = 0
countDust10 = 0



function readDustIN(timeMax,pin)
	print("\n\n#"..WatchDogCounter.."# Reading:"..(timeMax/1000000).." sek ");
	gpio.mode(pin, gpio.INPUT)
	local minimal = 1
	local appStart=tmr.now()
	local signals={};
	local signal  = 0
	local nr=0
	local terminator = false
	local divider = 1000

	dust25=0
	dust10=0
	countDust25=0
	countDust10=0

	while true do
		--loop for pluses
		gpio.write(5,0)
		while gpio.read(pin)==1 do 
			tmr.wdclr()
			if(tmr.now()-appStart > timeMax) then 
				terminator=true
				break 
			end		
		end

		--loop for minuses
		gpio.write(5,1)
		local signal=tmr.now()
		while gpio.read(pin)==0 do 
			if terminator then break end
			tmr.wdclr()
			if(tmr.now()-appStart > timeMax) then break end
			--tmr.delay(100)
		end

		local v = (tmr.now()-signal)/divider

		-- zapis
		if terminator==false then 
			table.insert(signals,v)
			
			if (v > minPoint and v < maxPoint) then 
				if (v < middlePoint) then 
					dust25=dust25+v 
					countDust25=countDust25+1 
					else 
					dust10=dust10+v 
					countDust10=countDust10+1 
				end
			end
			
		end
		gpio.write(5,0)
		if(tmr.now()-appStart > timeMax) then break end
		if (terminator==true) then break end
		tmr.wdclr()
	end
	
	local sig=''
	for k,v in pairs(signals) do 
		sig=sig..v..',' 
	end
	uart.write(0,'Signals='..sig..' => ')
			-- debug only
				--file.open("signals.txt.lua", "a+")
				--file.write(sig)
				--file.close()
			-- debug only
	sig=nil
	k=nil
	v=nil
end

loopStart = 0
loopStop  = 0
-- posting to INTERNET
function postThingSpeak()
	gpio.write(7,1)
	loopStart = tmr.now()
    connout = nil
    connout = net.createConnection(net.TCP, 0)
 
    connout:on("receive", function(connout, payloadout)
        if (string.find(payloadout, "Status: 200 OK") ~= nil) then
			uart.write(0,"Posted OK ... ")
			else WatchDogCounter = WatchDogCounter+10
        end
    end)
 
    connout:on("connection", function(connout, payloadout)

	local dataToSend = "&field1="..dust25.."&field2="..dust10.."&field3="..countDust25.."&field4="..countDust10.."&field5="..paramWIFI

        print ("Posting... "..dataToSend);   
        connout:send("GET /update?api_key=YOUR-API-KEY"..dataToSend
        .. " HTTP/1.1\r\n"
        .. "Host: api.thingspeak.com\r\n"
        .. "Connection: close\r\n"
        .. "Accept: */*\r\n"
        .. "User-Agent: Mozilla/4.0 (compatible; esp8266 Lua; Windows NT 5.1)\r\n"
        .. "\r\n")
    end)
 
    connout:on("disconnection", function(connout, payloadout)
        connout:close()
		loopStop = tmr.now()
		deltaTime = (loopStop - loopStart)/1000	
		if deltaTime < 500 then WatchDogCounter = WatchDogCounter-1 end
		if deltaTime > 1500 then WatchDogCounter = WatchDogCounter+10 end
		readWIFI()
		collectgarbage()
		--print("DISCONNECTION OK, Connection time="..deltaTime.."ms.".." onHeap="..node.heap())
		uart.write(0," DISCONNECTION OK, Connection time="..deltaTime.."ms.".." onHeap="..node.heap())
		
		gpio.write(7,0)
    end)
 
    connout:connect(80,'api.thingspeak.com')
	--connout:connect(80,'184.106.153.149') 
end
--! posting to INTERNET


-- MAIN LOOP
	function mainLOOP()
		tmr.softwd(300)	-- watchdog for 5 minutes
		WatchDogCounter = WatchDogCounter+1
		gpio.write(7,1)
		readDustIN(measurementTime,pin25Dust)
			dust25 = formula(dust25)
			dust10 = formula(dust10)
		gpio.write(7,0)
				--file.open("signals.txt.lua")
				--print(file.readline())
				--file.close()
		tmr.alarm(1, 5000, 0, function()
			print("MID="..middlePoint.."  P25:: "..countDust25.." X "..dust25..",  P10:: "..countDust10.." X "..dust10)
			postThingSpeak(0)	
		end)
		if (WatchDogCounter>59) then node.restart() end	-- restart after 60 minutes, that's for sure
	end
--! MAIN LOOP


readWIFI()	
	
tmr.alarm(2, 5000, 0, function() 
	mainLOOP()	
end)
tmr.alarm(0, mainLoopTime, 1, function() 
	mainLOOP()	
end)
