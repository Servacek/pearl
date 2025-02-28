-- Modified version inspired by http://lua-users.org/wiki/BaseSixtyFour

local base64 = {
    [0]='A',
    [1]='B',
    [2]='C',
    [3]='D',
    [4]='E',
    [5]='F',
    [6]='G',
    [7]='H',
    [8]='I',
    [9]='J',
    [10]='K',
    [11]='L',
    [12]='M',
    [13]='N',
    [14]='O',
    [15]='P',
    [16]='Q',
    [17]='R',
    [18]='S',
    [19]='T',
    [20]='U',
    [21]='V',
    [22]='W',
    [23]='X',
    [24]='Y',
    [25]='Z',
    [26]='a',
    [27]='b',
    [28]='c',
    [29]='d',
    [30]='e',
    [31]='f',
    [32]='g',
    [33]='h',
    [34]='i',
    [35]='j',
    [36]='k',
    [37]='l',
    [38]='m',
    [39]='n',
    [40]='o',
    [41]='p',
    [42]='q',
    [43]='r',
    [44]='s',
    [45]='t',
    [46]='u',
    [47]='v',
    [48]='w',
    [49]='x',
    [50]='y',
    [51]='z',
    [52]='0',
    [53]='1',
    [54]='2',
    [55]='3',
    [56]='4',
    [57]='5',
    [58]='6',
    [59]='7',
    [60]='8',
    [61]='9',
    [62]='-',
    [63]='_',
}

return function(data)
    if type(data) ~= "string" then
        return data
    end

	local bytes = {}
	local result = ""

	for spos = 0, #data - 1, 3 do
		for byte = 1, 3 do
            bytes[byte] = string.byte(
                string.sub(data,(spos + byte))
            ) or 0
        end

		result = string.format('%s%s%s%s%s', result,
            base64[bit.rshift(bytes[1], 2)],
            base64[bit.bor(bit.lshift((bytes[1] % 4), 4), bit.rshift(bytes[2], 4))] or "=",
            ((#data - spos) > 1) and base64[bit.bor(bit.lshift(bytes[2] % 16, 2), bit.rshift(bytes[3], 6))] or "=",
            ((#data - spos) > 2) and base64[(bytes[3] % 64)] or "="
        )
	end

	return result
end
