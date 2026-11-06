--[[
    ⚡ ZIP HUB (Optimized Wrapper based on Chilli Hub V4 Pro)
    - Tự động đổi toàn bộ UI và Text thành ZipHub
    - Giữ nguyên 100% chức năng gốc
    - Tối ưu bộ nhớ, dọn dẹp UI cũ trước khi load
]]

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Link gốc He đã gửi
local RAW_URL = "https://raw.githubusercontent.com/napun87/stealanegg/refs/heads/main/ChilliHub_V4_Pro-1.txt"

-- 1. DỌN DẸP UI CŨ (Tránh chồng chéo gây lag)
for _, parent in ipairs({CoreGui, PlayerGui}) do
    for _, gui in ipairs(parent:GetChildren()) do
        if gui:IsA("ScreenGui") then
            local name = string.lower(gui.Name)
            if string.find(name, "chilli") or string.find(name, "zip") then
                pcall(function() gui:Destroy() end)
            end
        end
    end
end

-- 2. TỰ ĐỘNG ĐỔI TÊN UI (Rebranding)
-- Vòng lặp ngầm quét mọi Text trên màn hình và đổi "Chilli" thành "ZipHub"
task.spawn(function()
    while task.wait(0.5) do
        for _, parent in ipairs({CoreGui, PlayerGui}) do
            for _, obj in ipairs(parent:GetDescendants()) do
                if (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) and obj.Text ~= "" then
                    local newText = obj.Text
                    -- Thay thế các biến thể của tên
                    newText = string.gsub(newText, "[Cc]hilli [Hh]ub", "ZipHub")
                    newText = string.gsub(newText, "[Cc]hilli[Hh]ub", "ZipHub")
                    newText = string.gsub(newText, "CHILLI HUB", "ZIP HUB")
                    newText = string.gsub(newText, "[Cc]hilli", "ZipHub")
                    newText = string.gsub(newText, "CHILLI", "ZIPHUB")
                    
                    if obj.Text ~= newText then
                        obj.Text = newText
                    end
                end
            end
        end
    end
end)

-- 3. TẢI VÀ CHẠY CODE GỐC
local success, err = pcall(function()
    local source = game:HttpGet(RAW_URL)
    
    -- Thay thế tên trực tiếp trong source code trước khi nạp
    source = string.gsub(source, "Chilli Hub", "ZipHub")
    source = string.gsub(source, "ChilliHub", "ZipHub")
    source = string.gsub(source, "CHILLI HUB", "ZIP HUB")
    
    -- Kích hoạt code
    local func, loadErr = loadstring(source)
    if not func then
        error("Lỗi cú pháp từ file gốc: " .. tostring(loadErr))
    end
    func()
end)

if success then
    print("[ZIP HUB] Đã load thành công bản Optimized (dựa trên Chilli Hub).")
else
    warn("[ZIP HUB] Lỗi tải script: " .. tostring(err))
    -- Fallback nếu link raw bị lỗi
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/tienkhanh1/spicy/main/Chilli.lua"))()
    end)
end
