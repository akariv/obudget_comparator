var page = require('webpage').create(),
    system = require('system'),
    address, output, size;

address = system.args[1];
size = system.args[2];
output = system.args[3];

if ( size == "s" ) {
    page.viewportSize = { width: 468, height: 808 };
} else if ( size == "m" ) {
    page.viewportSize = { width: 645, height: 733 };
} else if ( size == "l" ) {
    page.viewportSize = { width: 967, height: 658 };
}
page.clipRect = { left:4, top:4, width: page.viewportSize.width-8, height: page.viewportSize.height-8 };
page.open(address, function (status) {
    if (status !== 'success') {
        console.log('Unable to load the address!');
        phantom.exit();
    } else {
        window.setTimeout(function () {
            page.render(output);
            phantom.exit();
        }, 2000);
    }
});

