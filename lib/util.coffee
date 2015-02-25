### utility ###

module.exports.rand = rand = (n)->
	Math.floor Math.random() * n

module.exports.randf = (n)->
	Math.random * n

module.exports.randArray = (arr)->
	arr[rand arr.length]

module.exports.bitCount = (bits)->
	bits = (bits & 0x55555555) + (bits >> 1 & 0x55555555)
	bits = (bits & 0x33333333) + (bits >> 2 & 0x33333333)
	bits = (bits & 0x0f0f0f0f) + (bits >> 4 & 0x0f0f0f0f)
	bits = (bits & 0x00ff00ff) + (bits >> 8 & 0x00ff00ff)
	(bits & 0x0000ffff) + (bits >>16 & 0x0000ffff)

module.exports.toJSTtime = (time)->
	time + 32400000

module.exports.toJST = (date)->
	d = new Date()
	d.setTime(date.getTime() + 32400000)
	d

module.exports.JSTDate = ()->
	d = new Date()
	d.setTime(d.getTime() + 32400000)
	d

module.exports.zeroFill = (num, n)->
	("0" + num).slice(-n)

module.exports.dateStr = (date_)->
	date = new Date(date_);
	date.getFullYear() + "/" + zeroFill(date.getMonth()+1,2) + "/" + zeroFill(date.getDate(),2) + " " + zeroFill(date.getHours(),2) + ":" + zeroFill(date.getMinutes(),2) + ":" + zeroFill(date.getSeconds(),2)
