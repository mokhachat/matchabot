var MilkCocoa = require("./index.js");

var milkcocoa = new MilkCocoa("https://io-ti2dak0ql.mlkcca.com");
var ds = milkcocoa.dataStore("nodejs");
ds.on("push", function(r) {
	console.log(r);
});
ds.push({ text : "あああいうえお"});
