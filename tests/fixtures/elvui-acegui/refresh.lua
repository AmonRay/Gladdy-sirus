function S:Ace3_RefreshTree(scrollToSelection)
	self.old_RefreshTree(self, scrollToSelection)

	local tree = self.tree
	if not tree then return end

	local border = self.border
	local treeframe = self.treeframe
	if border and treeframe then
		border:ClearAllPoints()

		local userdata = self.userdata
		local dataoption = userdata and userdata.option
		if dataoption and dataoption.childGroups == 'ElvUI_HiddenTree' then
			border:Point('TOPLEFT', treeframe, 'TOPRIGHT', 1, -1)
			border:Point('BOTTOMRIGHT', self.frame, 'BOTTOMRIGHT', 0, 0)

			treeframe:Point('TOPLEFT', 0, 0)

			if treeframe:IsShown() then
				treeframe:Hide()
			end

			return -- dont proceed
		else
			border:Point('TOPLEFT', treeframe, 'TOPRIGHT')
			border:Point('BOTTOMRIGHT', self.frame)

			treeframe:Point('TOPLEFT', 0, -2)

			if not treeframe:IsShown() then
				treeframe:Show()
			end
		end
	end

	if not E.private.skins.ace3Enable then return end

	local lines = self.lines
	local buttons = self.buttons
	if lines and buttons then
		local status = self.status or self.localstatus
		local offset = status.scrollvalue
		local groupstatus = status.groups

		for i = offset + 1, #lines do
			local button = buttons[i - offset]
			if button then
				if button.highlight then
					button.highlight:SetVertexColor(1.0, 0.9, 0.0, 0.8)
				end

				local line = lines[i]
				local unique = line and line.uniquevalue
				if unique and groupstatus[unique] then
					button.toggle:SetNormalTexture(E.Media.Textures.Minus)
					button.toggle:SetPushedTexture(E.Media.Textures.Minus)
				else
					button.toggle:SetNormalTexture(E.Media.Textures.Plus)
					button.toggle:SetPushedTexture(E.Media.Textures.Plus)
				end

				button.toggle:SetHighlightTexture(E.ClearTexture)
			end
		end
	end
end
