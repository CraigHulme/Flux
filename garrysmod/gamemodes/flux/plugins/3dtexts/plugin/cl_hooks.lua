local blurTexture = Material('pp/blurscreen')
local color_white = Color(255, 255, 255)

function fl3DText:DrawTextPreview()
  local tool = fl.client:GetTool()
  local text = tool:GetClientInfo('text')
  local style = tool:GetClientNumber('style')
  local trace = fl.client:GetEyeTrace()
  local normal = trace.HitNormal
  local w, h = util.text_size(text, theme.get_font('text_3d2d'))
  local angle = normal:Angle()
  angle:RotateAroundAxis(angle:Forward(), 90)
  angle:RotateAroundAxis(angle:Right(), 270)

  cam.Start3D2D(trace.HitPos + (normal * 1.25), angle, 0.1 * tool:GetClientNumber('scale'))
    if style >= 5 then
      if style != 8 and style != 9 then
        draw.RoundedBox(0, -w * 0.5 - 32, -h * 0.5 - 16, w + 64, h + 32, Color(tool:GetClientNumber('r2', 0), tool:GetClientNumber('g2', 0), tool:GetClientNumber('b2', 0), 40))
      end

      if style == 7 or style == 8 then
        draw.RoundedBox(0, -w * 0.5 - 32, -h * 0.5 - 16, w + 64, 6, Color(255, 255, 255, 40))
        draw.RoundedBox(0, -w * 0.5 - 32, -h * 0.5 + h + 10, w + 64, 6, Color(255, 255, 255, 40))
      elseif style == 9 then
        local wide = w + 64
        local barColor = Color(255, 255, 255, 40)
        local barX, bar_y = -w * 0.5 - 32, -h * 0.5 - 16
        local rectWidth = (wide / 3 - wide / 6) * 0.75

        -- Draw left thick rectangles
        draw.RoundedBox(0, barX, bar_y - 6, rectWidth, 10, barColor)
        draw.RoundedBox(0, barX, bar_y + h + 22, rectWidth, 10, barColor)

        -- ...and the right ones
        draw.RoundedBox(0, barX + wide - rectWidth, bar_y - 6, rectWidth, 10, barColor)
        draw.RoundedBox(0, barX + wide - rectWidth, bar_y + h + 22, rectWidth, 10, barColor)

        -- And the middle thingies
        draw.RoundedBox(0, -(wide / 1.75) * 0.5, bar_y, wide / 1.75, 4, barColor)
        draw.RoundedBox(0, -(wide / 1.75) * 0.5, bar_y + h + 22, wide / 1.75, 4, barColor)
      end
    end

    draw.SimpleText(text, theme.get_font('text_3d2d'), -w * 0.5, -h * 0.5, Color(tool:GetClientNumber('r', 0), tool:GetClientNumber('g', 0), tool:GetClientNumber('b', 0), 60))
  cam.End3D2D()
end

function fl3DText:DrawPicturePreview()
  local tool = fl.client:GetTool()
  local url = tool:GetClientInfo('url')
  local width = tool:GetClientNumber('width')
  local height = tool:GetClientNumber('height')
  local trace = fl.client:GetEyeTrace()
  local normal = trace.HitNormal
  local angle = normal:Angle()
  angle:RotateAroundAxis(angle:Forward(), 90)
  angle:RotateAroundAxis(angle:Right(), 270)

  cam.Start3D2D(trace.HitPos + (normal * 1.25), angle, 0.1)
    if url:ends('.png') or url:ends('.jpg') or url:ends('.jpeg') then
      draw.textured_rect(URLMaterial(url), -width * 0.5, -height * 0.5, width, height, color_white)
    else
      draw.RoundedBox(0, -width * 0.5, -height * 0.5, width, height, Color(255, 0, 0, 40))      
    end
  cam.End3D2D()
end

function fl3DText:PostDrawOpaqueRenderables()
  local weapon = fl.client:GetActiveWeapon()
  local clientPos = fl.client:GetPos()

  if IsValid(weapon) and weapon:GetClass() == 'gmod_tool' then
    local mode = weapon:GetMode()

    if mode == 'texts' then
      self:DrawTextPreview()
    elseif mode == 'pictures' then
      self:DrawPicturePreview()
    end
  end

  for k, v in ipairs(self.texts) do
    local pos = v.pos
    local distance = clientPos:Distance(pos)
    local fadeOffset = v.fadeOffset or 1000
    local drawDistance = (1024 + fadeOffset)

    if distance > drawDistance then continue end

    local fadeAlpha = 255
    local fadeDistance = (768 + fadeOffset)

    if distance > fadeDistance then
      local d = distance - fadeDistance
      fadeAlpha = math.Clamp((255 * ((drawDistance - fadeDistance) - d) / (drawDistance - fadeDistance)), 0, 255)
    end

    local angle = v.angle
    local normal = v.normal
    local scale = v.scale
    local text = v.text
    local textColor = v.color
    local backColor = v.extraColor
    local style = v.style
    local w, h = util.text_size(text, theme.get_font('text_3d2d'))
    local posX, posY = -w * 0.5, -h * 0.5

    if style >= 2 then
      cam.Start3D2D(pos + (normal * 0.4), angle, 0.1 * scale)
        if style >= 5 then
          local boxAlpha = backColor.a
          local boxX, boxY = posX - 32, posY - 16

          if style == 6 then
            boxAlpha = boxAlpha * math.abs(math.sin(CurTime() * 3))
          end

          if style == 10 then
            render.ClearStencil()
            render.SetStencilEnable(true)
            render.SetStencilCompareFunction(STENCIL_ALWAYS)
            render.SetStencilPassOperation(STENCIL_REPLACE)
            render.SetStencilFailOperation(STENCIL_KEEP)
            render.SetStencilZFailOperation(STENCIL_KEEP)
            render.SetStencilWriteMask(254)
            render.SetStencilTestMask(254)
            render.SetStencilReferenceValue(ref or 75)

            surface.SetDrawColor(255, 255, 255, 10)
            surface.DrawRect(boxX, boxY, w + 64, h + 32)

            render.SetStencilCompareFunction(STENCIL_EQUAL)

            render.SetMaterial(blurTexture)

            for i = 0, 1, 0.3 do
              blurTexture:SetFloat('$blur', i * 8)
              blurTexture:Recompute()
              render.UpdateScreenEffectTexture()
              render.DrawScreenQuad()
            end

            render.SetStencilEnable(false)

            surface.SetDrawColor(ColorAlpha(backColor, 10))
            surface.DrawRect(boxX, boxY, w + 64, h + 32)
          elseif style != 8 and style != 9 then
            draw.RoundedBox(0, boxX, posY - 16, w + 64, h + 32, ColorAlpha(v.extraColor, math.Clamp(fadeAlpha, 0, boxAlpha)))
          end

          if style == 7 or style == 8 then
            local barColor = Color(255, 255, 255, math.Clamp(fadeAlpha, 0, boxAlpha))

            draw.RoundedBox(0, boxX, boxY, w + 64, 6, barColor)
            draw.RoundedBox(0, boxX, boxY + h + 26, w + 64, 6, barColor)
          elseif style == 9 then
            local tall, wide = 6, w + 64
            local rectWidth = (wide / 3 - wide / 6) * 0.75
            local barColor = Color(255, 255, 255, math.Clamp(fadeAlpha, 0, boxAlpha))

            -- Draw left thick rectangles
            draw.RoundedBox(0, boxX, boxY - 6, rectWidth, 10, barColor)
            draw.RoundedBox(0, boxX, boxY + h + 22, rectWidth, 10, barColor)

            -- ...and the right ones
            draw.RoundedBox(0, boxX + wide - rectWidth, boxY - 6, rectWidth, 10, barColor)
            draw.RoundedBox(0, boxX + wide - rectWidth, boxY + h + 22, rectWidth, 10, barColor)

            -- And the middle thingies
            draw.RoundedBox(0, -(wide / 1.75) * 0.5, boxY, wide / 1.75, 4, barColor)
            draw.RoundedBox(0, -(wide / 1.75) * 0.5, boxY + h + 22, wide / 1.75, 4, barColor)
          end
        end

        if style != 3 then
          draw.SimpleText(text, theme.get_font('text_3d2d'), posX, posY, ColorAlpha(textColor, math.Clamp(fadeAlpha, 0, 100)):darken(30))
        end
      cam.End3D2D()
    end

    if style >= 3 then
      cam.Start3D2D(pos + (normal * 0.95 * (scale + 0.5)), angle, 0.1 * scale)
        draw.SimpleText(text, theme.get_font('text_3d2d'), posX, posY, Color(0, 0, 0, math.Clamp(fadeAlpha, 0, 240)))
      cam.End3D2D()
    end

    cam.Start3D2D(pos + (normal * 1.25 * (scale + 0.5)), angle, 0.1 * scale)
      draw.SimpleText(text, theme.get_font('text_3d2d'), posX, posY, ColorAlpha(textColor, fadeAlpha))
    cam.End3D2D()
  end

  for k, v in ipairs(self.pictures) do
    local pos = v.pos
    local distance = clientPos:Distance(pos)
    local fade_offset = v.fade_offset or 1000
    local draw_distance = 1024 + fade_offset

    if distance > draw_distance then continue end

    local fade_alpha = 255
    local fade_distance = 768 + fade_offset

    if distance > fade_distance then
      local d = distance - fade_distance
      fade_alpha = math.Clamp((255 * ((draw_distance - fade_distance) - d) / (draw_distance - fade_distance)), 0, 255)
    end

    local height = v.height
    local width = v.width

    cam.Start3D2D(pos + (v.normal * 0.4), v.angle, 0.1)
      draw.textured_rect(URLMaterial(v.url), -width * 0.5, -height * 0.5, width, height, ColorAlpha(color_white, fade_alpha))
    cam.End3D2D()
  end
end
