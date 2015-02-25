milkcocoa for Node.js


-----


    var MilkCocoa = require("./index.js");
    var milkcocoa = new MilkCocoa("https://{your-app-id}.mlkcca.com");
    var ds = milkcocoa.dataStore("nodejs");
    ds.on("push", function(r) {
	    console.log(r);
    });
    ds.push({ text : "OK"});
