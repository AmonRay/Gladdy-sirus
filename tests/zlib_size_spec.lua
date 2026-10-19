local passed = 0
local function test(name, fn)
    local ok, err = xpcall(fn, debug.traceback); assert(ok, name .. ': ' .. tostring(err))
    passed = passed + 1; print('ok ' .. passed .. ' - ' .. name)
end
strmatch=string.match
dofile('Gladdy/Libs/Ace3/LibStub/LibStub.lua')
local G = LibStub:NewLibrary('Gladdy', 1)
dofile('Gladdy/Libs/LibDeflate/LibDeflate.lua')
dofile('Gladdy/ImportValidation.lua')
local deflate = LibStub('LibDeflate')
local function compress(raw, config) return deflate:CompressZlib(raw, config) end
local samples = {'', 'a', string.rep('abc123', 15000)}
local bytes = {}; for i = 0, 255 do bytes[#bytes + 1] = string.char(i) end
samples[#samples + 1] = table.concat(bytes)
for _, strategy in ipairs({'fixed','dynamic','huffman_only'}) do
    test(strategy .. ' streams produce the exact output count', function()
        for _, raw in ipairs(samples) do
            local encoded = compress(raw, {level = 5, strategy = strategy})
            assert(G:ValidateZlibSize(encoded, #raw) == #raw)
            assert(deflate:DecompressZlib(encoded) == raw)
            if #raw > 0 then assert(G:ValidateZlibSize(encoded, #raw - 1) == nil) end
        end
    end)
end
test('stored multi-block streams handle alignment and exact limits', function()
    local raw = string.rep(table.concat(bytes), 600)
    local encoded = compress(raw, {level = 0})
    assert(G:ValidateZlibSize(encoded, #raw) == #raw)
    assert(G:ValidateZlibSize(encoded, #raw - 1) == nil)
end)
test('truncation trailing data dictionaries and invalid headers fail closed', function()
    local encoded = compress('test profile')
    for i = 1, #encoded - 1 do assert(G:ValidateZlibSize(encoded:sub(1, i), 100) == nil) end
    assert(G:ValidateZlibSize(encoded .. 'trailing', 100) == nil)
    assert(G:ValidateZlibSize(string.char(0x78, 0x20) .. encoded:sub(3), 100) == nil)
    assert(G:ValidateZlibSize('not zlib', 100) == nil)
    assert(G:ValidateZlibSize(nil, 100) == nil and G:ValidateZlibSize(encoded, -1) == nil)
end)
test('reserved block types and invalid stored lengths are rejected', function()
    assert(G:ValidateZlibSize(string.char(0x78,0x9c,7,0,0,0,1), 100) == nil)
    assert(G:ValidateZlibSize(string.char(0x78,0x01,1,1,0,0,0,65,0,0,0,0), 100) == nil)
end)
test('high-ratio payload is rejected without creating expanded output', function()
    local raw = string.rep('x', 2097153)
    local encoded = compress(raw, {level = 5})
    assert(#encoded < 20000)
    local size, err = G:ValidateZlibSize(encoded, 2097152)
    assert(size == nil and err:find('size limit'))
end)
print('PASS: ' .. passed .. ' compressed size guard tests')
