// Artwork uses a fixed design space. Output grid size never changes geometry.
function sizeWithin(width, height, maxWidth, maxHeight) {
    var w = Math.max(1, width), h = Math.max(1, height);
    var factor = Math.min(1, maxWidth / w, maxHeight / h);
    return { columns: Math.max(1, Math.round(w * factor)), rows: Math.max(1, Math.round(h * factor)) };
}
function grid(width, height, cellSize) {
    var cell = Math.max(2, Math.min(20, cellSize || 4));
    return sizeWithin(Math.ceil(width / cell), Math.ceil(height / cell), 960, 600);
}
function sourceSize(width, height) {
    // Stable source density at a given aspect, independent of desktop/detail size.
    var aspect = Math.max(1, width) / Math.max(1, height);
    return sizeWithin(Math.max(1280, 720 * aspect), Math.max(720, 1280 / aspect), 1600, 1000);
}
function advance(time, seconds, speed) {
    return time + Math.max(0, Math.min(0.1, seconds)) * Math.max(1, Math.min(20, speed)) / 10;
}
function blendColor(a, b, amount, brightness) {
    var result = "#";
    for (var i = 1; i < 7; i += 2) {
        var value = Math.round((parseInt(a.slice(i,i+2),16) * (1-amount) + parseInt(b.slice(i,i+2),16) * amount) * brightness);
        result += ("0" + Math.max(0, Math.min(255,value)).toString(16)).slice(-2);
    }
    return result;
}
function sky(ctx, width, height, state) {
    ctx.reset();
    var warm = ["#754476", "#df6887", "#ffc982"], cool = ["#53677f", "#9daab8", "#c9cbd0"];
    var amount = (1-state.warmth) / 2;
    var gradient = ctx.createLinearGradient(0, 0, 0, height * 0.72);
    gradient.addColorStop(0, blendColor(warm[0],cool[0],amount,state.brightness));
    gradient.addColorStop(0.48, blendColor(warm[1],cool[1],amount,state.brightness));
    gradient.addColorStop(1, blendColor(warm[2],cool[2],amount,state.brightness));
    ctx.fillStyle = gradient; ctx.fillRect(0, 0, width, height);
    if (state.sunStrength <= 0) return;
    var x = width * state.sunX, y = height * state.sunY;
    var radius = Math.min(width / 1280, height / 720) * 32;
    ctx.globalAlpha = state.sunStrength;
    var glow = ctx.createRadialGradient(x, y, radius, x, y, radius * 3.6);
    glow.addColorStop(0, "rgba(255,224,132," + (0.4*Math.min(1,state.brightness)) + ")"); glow.addColorStop(1, "rgba(255,224,132,0)");
    ctx.fillStyle = glow; ctx.fillRect(x-radius*4,y-radius*4,radius*8,radius*8);
    ctx.fillStyle = blendColor("#fff3ac", "#edf1f3",amount,state.brightness);
    ctx.beginPath(); ctx.ellipse(x-radius,y-radius,radius*2,radius*2); ctx.fill();
    ctx.globalAlpha = 1;
}
function gradePixel(r, g, b, brightness, warmth, cloud, darkness) {
    var light = r*0.2126 + g*0.7152 + b*0.0722;
    var cool = (1-warmth)/2;
    if (cloud) {
        var neutral = cool + darkness * (1-cool);
        var grey = (94 + light*0.61) * (1-darkness) + (36 + light*0.4) * darkness;
        return [(r*(1-neutral)+grey*neutral*0.94)*brightness,
                (g*(1-neutral)+grey*neutral)*brightness,
                (b*(1-neutral)+grey*neutral*1.06)*brightness];
    }
    var saturation = 1-cool*0.88;
    return [(r*saturation+light*(1-saturation))*(1-cool*0.28)*brightness,
            (g*saturation+light*(1-saturation))*(1-cool*0.05)*brightness,
            (b*saturation+light*(1-saturation))*(1+cool*0.14)*brightness];
}
function grade(ctx, width, height, brightness, warmth, cloud, darkness) {
    if (brightness === 1 && warmth === 1 && (!cloud || darkness === 0)) return;
    // Read/process only when an asset, source size or weather changes. Alpha is
    // left intact, including translucent cloud wisps and canopy/sky boundaries.
    var image = ctx.getImageData(0, 0, width, height);
    var pixels = image.data;
    for (var i = 0; i < pixels.length; i += 4) {
        if (!pixels[i + 3]) continue;
        var color = gradePixel(pixels[i], pixels[i + 1], pixels[i + 2], brightness, warmth, cloud, darkness);
        pixels[i] = color[0]; pixels[i + 1] = color[1]; pixels[i + 2] = color[2];
    }
    // Replace the source pixels rather than blending them over their old alpha.
    ctx.reset();
    // Qt requires the explicit dirty rectangle here; the short form was a no-op
    // on the installed runtime. Pixel tests cover the cached graded result.
    ctx.putImageData(image, 0, 0, 0, 0, width, height);
}
function asset(ctx, width, height, image, brightness, warmth, cloud, darkness) {
    ctx.reset();
    // Fit the asset width, anchor terrain to the bottom, and extend the sky on
    // taller screens. Wide screens crop vertically without distorting artwork.
    // Both original project assets are 1672 x 941; keep that aspect intact.
    var artHeight = width * 941 / 1672;
    var y = cloud ? 0 : height - artHeight;
    ctx.drawImage(image, 0, y, width, artHeight);
    grade(ctx, width, height, brightness, warmth, cloud, darkness);
}
function cloudPlacements(width, height, phase) {
    // Crossfade at invisible wrap points: both copies travel in the signed
    // wind direction while their image edges stay outside the viewport.
    // Align the approved phase-12 reference with one fully visible copy.
    var cycle = (((phase-12)/150 + 0.5) % 1 + 1) % 1;
    var layers = [];
    for (var i=0; i<2; i++) {
        var step = (cycle+i*0.5) % 1;
        layers.push({x: -width*0.06 + Math.sin(12/75)*width*0.04 + (step-0.5)*width*0.08,
                     y: -height*0.06 + Math.sin(phase/110)*height*0.01,
                     width: width*1.12, height: height*1.12,
                     opacity: Math.pow(Math.sin(Math.PI*step),2)});
    }
    return layers;
}
