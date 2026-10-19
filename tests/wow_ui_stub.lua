local M = { errors = {}, hooks = {}, names = {}, templateText = 'text' }
local methods = {}
local mt = {__index = function(_, key) return methods[key] or (key:match('^[A-Z]') and function() end or nil) end}
local function object(kind, name, parent)
    local obj = setmetatable({kind=kind,name=name,parent=parent,scripts={},children={},regions={},points={},shown=true,_width=300,_height=600,textValue=''}, mt)
    if name then assert(_G[name] == nil, 'duplicate global: '..name); _G[name]=obj; M.names[#M.names+1]=name end
    if parent then parent.children[#parent.children+1]=obj end
    return obj
end
function methods:GetName() return self.name end
function methods:GetParent() return self.parent end
function methods:SetParent(parent) self.parent=parent end
function methods:GetChildren() return unpack(self.children) end
function methods:GetRegions() return unpack(self.regions) end
function methods:GetObjectType() return self.kind end
function methods:IsObjectType(kind) return self.kind==kind end
function methods:SetScript(event,fn) assert(fn==nil or type(fn)=='function'); self.scripts[event]=fn end
function methods:GetScript(event) return self.scripts[event] end
function methods:HookScript(event,fn)
    local old=self.scripts[event]; self.scripts[event]=function(...) if old then old(...) end; fn(...) end
end
function methods:SetWidth(v) self._width=v end
function methods:SetHeight(v) self._height=v end
function methods:GetWidth() return self._width end
function methods:GetHeight() return self._height end
function methods:SetSize(w,h) self._width=w; self._height=h end
function methods:SetText(text) self.textValue=text or '' end
function methods:GetText() return self.textValue end
function methods:GetStringWidth() return #tostring(self.textValue)*6 end
function methods:GetStringHeight() return 14 end
function methods:SetFont(font,size,flags) self.font={font,size,flags} end
function methods:GetFont() return unpack(self.font or {'font',12,''}) end
function methods:SetPoint(...) self.points[#self.points+1]={...} end
function methods:GetPoint(i) return unpack(self.points[i or 1] or {'TOPLEFT',self.parent,'TOPLEFT',0,0}) end
function methods:ClearAllPoints() self.points={} end
function methods:GetFrameLevel() return self.level or 1 end
function methods:SetFrameLevel(v) self.level=v end
function methods:GetScale() return 1 end
function methods:GetEffectiveScale() return 1 end
function methods:GetLeft() return 0 end
function methods:GetRight() return self._width end
function methods:GetTop() return self._height end
function methods:GetBottom() return 0 end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown end
function methods:SetValue(v) self.value=v end
function methods:GetValue() return self.value or 0 end
function methods:GetMinMaxValues() return 0,100 end
function methods:GetChecked() return self.checked end
function methods:SetChecked(v) self.checked=v end
function methods:CreateTexture(name) local r=object('Texture',name); self.regions[#self.regions+1]=r; return r end
function methods:CreateFontString(name) local r=object('FontString',name); self.regions[#self.regions+1]=r; return r end
function methods:GetHighlightTexture() self.highlightTexture=self.highlightTexture or self:CreateTexture(); return self.highlightTexture end
function methods:GetNormalTexture() self.normalTexture=self.normalTexture or self:CreateTexture(); return self.normalTexture end
function methods:GetPushedTexture() self.pushedTexture=self.pushedTexture or self:CreateTexture(); return self.pushedTexture end
function methods:HasFocus() return false end
function methods:GetNumPoints() return #self.points end
function methods:GetNumLetters() return #self.textValue end
function methods:GetCursorPosition() return #self.textValue end
function methods:GetNumLines() return 1 end
function methods:GetVerticalScroll() return 0 end
function methods:GetVerticalScrollRange() return 0 end
function methods:GetValueStep() return 1 end
function methods:GetScrollChild() return self.scrollChild end
function methods:SetScrollChild(child) self.scrollChild=child end
function methods:GetHorizontalScroll() return 0 end
function methods:GetFontString() self.fontString=self.fontString or self:CreateFontString(); return self.fontString end
function methods:GetFontObject() return GameFontNormal end
function methods:GetTextColor() return 1,1,1,1 end
function methods:IsEnabled() return true end
function methods:GetAlpha() return 1 end
function methods:GetBackdropColor() return 0,0,0,1 end
function methods:GetBackdropBorderColor() return 1,1,1,1 end
function M.install()
    wipe=function(t) for k in pairs(t) do t[k]=nil end; return t end
    string.split=function(sep,text)
        local result={}; local position=1
        while true do
            local i,j=text:find(sep,position,true)
            if not i then result[#result+1]=text:sub(position); break end
            result[#result+1]=text:sub(position,i-1); position=j+1
        end
        return unpack(result)
    end
    UISpecialFrames={};
    table.wipe=wipe; floor=math.floor; ceil=math.ceil; max=math.max; min=math.min; strmatch=string.match
    SetDesaturation=function() end
    GetTime=function() return 100 end; GetLocale=function() return 'ruRU' end
    GetBuildInfo=function() return '3.3.5','12340','',30300 end
    GetCursorPosition=function() return 0,0 end
    IsShiftKeyDown=function() return false end; IsControlKeyDown=IsShiftKeyDown; IsAltKeyDown=IsShiftKeyDown
    GetCVar=function() return '0' end; PlaySound=function() end
    geterrorhandler=function() return function(err) M.errors[#M.errors+1]=err end end
    hooksecurefunc=function(name,fn) M.hooks[name]=M.hooks[name] or {}; table.insert(M.hooks[name],fn) end
    CreateFont=function(name) return object('Font',name) end
    CreateFrame=function(kind,name,parent,template)
        local f=object(kind,name,parent)
        if template=='OptionsListButtonTemplate' then
            f[M.templateText]=f:CreateFontString(name and name..'Text')
            f.toggle=object('Button',name and name..'Toggle',f)
        elseif template=='UIDropDownMenuTemplate' then
            for _,suffix in ipairs({'Left','Middle','Right','Button','Text'}) do
                local r=object(suffix=='Button' and 'Button' or 'Texture',name..suffix,f)
                f[suffix]=r
            end
        elseif template=='InputBoxTemplate' then f.Left=f:CreateTexture(); f.Middle=f:CreateTexture(); f.Right=f:CreateTexture()
        elseif template=='UIPanelScrollFrameTemplate' then f.ScrollBar=object('Slider',name..'ScrollBar',f) end
        return f
    end
    UIParent=CreateFrame('Frame','UIParent')
    InterfaceOptionsFramePanelContainer=CreateFrame('Frame','InterfaceOptionsFramePanelContainer',UIParent)
    GameFontNormal=CreateFont('GameFontNormal'); GameFontHighlight=CreateFont('GameFontHighlight')
    GameTooltip=CreateFrame('GameTooltip','GameTooltip')
    ColorPickerFrame=CreateFrame('Frame','ColorPickerFrame')
    OpacitySliderFrame=CreateFrame('Slider','OpacitySliderFrame')
    DEFAULT_CHAT_FRAME={AddMessage=function() end}
    FONT_COLOR_CODE_CLOSE='|r'; OKAY='OK'; CANCEL='Cancel'; ACCEPT='Accept'; YES='Yes'; NO='No'; CLOSE='Close'
    InterfaceOptions_AddCategory=function() end
    ChatEdit_InsertLink=function() end
end
return M
