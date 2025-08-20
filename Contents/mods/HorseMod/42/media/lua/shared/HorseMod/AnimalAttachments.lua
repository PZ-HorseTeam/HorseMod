local group = AttachedLocations.getGroup("Animal")
-- Create a new attachment point named "Back" for backpacks or similar gear
local back = group:getOrCreateLocation("Back")
back:setAttachmentName("back")