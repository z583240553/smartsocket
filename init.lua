local _M = {}
local bit = require "bit"
local cjson = require "cjson.safe"
local Json = cjson.encode

local strload

--Json的Key，用于协议帧头的几个数据
local cmds = {
  [0] = "length",
  [1] = "DTU_time",
  [2] = "DTU_status",
  [3] = "DTU_function",
  [4] = "device_address"
}

--Json的Key，用于清洁车云端显示状态
local status_cmds = {
  [1] = "TotalActivePower",     --有功总电量
  [2] = "PositiveActivePower",  --正向有功电量
  [3] = "ReverseActivePower",   --反向有功电量
  [4] = "Voltage",           	--电压
  [5] = "Current",           	--电流
  [6] = "ActivePower",       	--有功功率
}

--FCS校验
function utilCalcFCS( pBuf , len )
  local rtrn = 0
  local l = len

  while (len ~= 0)
    do
    len = len - 1
    rtrn = bit.bxor( rtrn , pBuf[l-len] )
  end

  return rtrn
end

--将字符转换为数字
function getnumber( index )
   return string.byte(strload,index)
end

--编码 /in 频道的数据包
function _M.encode(payload)
  return payload
end

--解码 /out 频道的数据包
function _M.decode(payload)
	local packet = {['status']='not'}

	--FCS校验的数组(table)，用于逐个存储每个Byte的数值
	local FCS_Array = {}

	--用来直接读取发来的数值，并进行校验
	local FCS_Value = 0

	--strload是全局变量，唯一的作用是在getnumber函数中使用
	strload = payload

	--前2个Byte是帧头，正常情况应该为';'和'1'
	local head1 = getnumber(1)
	local head2 = getnumber(2)

	--当帧头符合，才进行其他位的解码工作
	if ( (head1 == 0x3B) and (head2 == 0x31) ) then

		--数据长度
		local templen = bit.lshift( getnumber(3) , 8 ) + getnumber(4)

		FCS_Value = bit.lshift( getnumber(templen+5) , 8 ) + getnumber(templen+6)

		--将全部需要进行FCS校验的Byte写入FCS_Array这个table中
		for i=1,templen+4,1 do
			table.insert(FCS_Array,getnumber(i))
		end

		--进行FCS校验，如果计算值与读取指相等，则此包数据有效；否则弃之
		if(utilCalcFCS(FCS_Array,#FCS_Array) == FCS_Value) then
			packet['status'] = 'SUCCESS'
		else
			packet = {}
			packet['status'] = 'FCS-ERROR'
			return Json(packet)
		end

		--数据长度
		--packet[ cmds[0] ] = templen
		--运行时长
		packet[ cmds[1] ] = bit.lshift( getnumber(5) , 24 ) + bit.lshift( getnumber(6) , 16 ) + bit.lshift( getnumber(7) , 8 ) + getnumber(8)
		--采集模式
		--[[local mode = getnumber(9)
		if mode == 1 then
			packet[ cmds[2] ] = 'Mode-485'
			else
			packet[ cmds[2] ] = 'Mode-232'
		end--]]
		--func为判断是 实时数据/参数/故障 的参数
		local func = getnumber(10)
		if func == 1 then  --解析电量数据
			--packet[ cmds[3] ] = 'func-status'
			--设备modbus地址
			--packet[ cmds[4] ] = getnumber(11)

			--依次读入上传的数据
			--有功总电量
			packet[status_cmds[1]] = (getnumber(12)*1000000+getnumber(13)*10000+getnumber(14)*100+getnumber(15))/100
			--正向有功电量
			packet[status_cmds[2]] = (getnumber(16)*1000000+getnumber(17)*10000+getnumber(18)*100+getnumber(19))/100 
			--反向有功电量
			packet[status_cmds[3]] = (getnumber(20)*1000000+getnumber(21)*10000+getnumber(22)*100+getnumber(23))/100 
			--电压
			packet[status_cmds[4]] = (getnumber(24)*100+getnumber(25))/10
			--电流
			packet[status_cmds[5]] = (getnumber(26)*1000000+getnumber(27)*10000+getnumber(28)*100+getnumber(29))/1000 
			--有功功率
			packet[status_cmds[6]] = (getnumber(30)*1000000+getnumber(31)*10000+getnumber(32)*100+getnumber(33))/10000 
		end

	else
		packet['head_error'] = 'error'
	end

	return Json(packet)
end

return _M
