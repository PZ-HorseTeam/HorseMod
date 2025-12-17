local AttachmentData = require("HorseMod/attachments/AttachmentData")

---Define a new model attachment point called leftAttachTestPoint on the horse model.
AttachmentData.addNewModelAttachment("leftAttachTestPoint", {
    bone = "DEF_Spine2",
    offset = {x=-0.3, y=0.1528, z=0.041},
    rotate = {x=0.0, y=0.0, z=0.0},
})

---Define a new attachment slot called LeftAttachTestPoint which is linked to the model attachment point defined above.
AttachmentData.addNewSlot("LeftAttachTestPoint", {
    modelAttachment = "leftAttachTestPoint",
})

---Define a new attachment using the item full type "Base.Sword" which can be attached to the LeftAttachTestPoint slot.
local attachmentDef = {} -- empty because no custom data associated to that attachment
AttachmentData.addNewAttachment("Base.Sword", "LeftAttachTestPoint", attachmentDef)