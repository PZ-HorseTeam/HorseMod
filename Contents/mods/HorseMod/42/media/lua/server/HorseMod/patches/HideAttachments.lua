local AttachmentData = require("HorseMod/attachments/AttachmentData")

local function hideAttachments()
    for fullType, _ in pairs(AttachmentData.containerItems) do
        ISSearchManager.ignoredItemTypes[fullType] = true
    end
end

AttachmentData.postLoadAttachments:add(hideAttachments)
