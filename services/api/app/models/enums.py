from enum import Enum


class DamType(str, Enum):
    earthfill = "earthfill"
    rockfill = "rockfill"
    concrete = "concrete"
    masonry = "masonry"


class InspectionType(str, Enum):
    routine = "routine"
    pre_flood = "pre_flood"
    post_flood = "post_flood"
    special = "special"
    safety_review = "safety_review"


class TaskStatus(str, Enum):
    draft = "draft"
    in_progress = "in_progress"
    completed = "completed"


class ItemType(str, Enum):
    chapter = "chapter"
    section = "section"
    inspection_item = "inspection_item"


class CheckStatus(str, Enum):
    unchecked = "unchecked"
    normal = "normal"
    basically_normal = "basically_normal"
    abnormal = "abnormal"
    not_applicable = "not_applicable"


class SeverityLevel(str, Enum):
    minor = "minor"
    moderate = "moderate"
    serious = "serious"
    critical = "critical"


class EvidenceType(str, Enum):
    photo = "photo"
    audio = "audio"
    video = "video"
    attachment = "attachment"


class ExportType(str, Enum):
    inspection_form = "inspection_form"
    issue_list = "issue_list"
    photo_appendix = "photo_appendix"


class FileFormat(str, Enum):
    docx = "docx"
    xlsx = "xlsx"
    pdf = "pdf"


class SyncStatus(str, Enum):
    pending = "pending"
    synced = "synced"
    failed = "failed"


class CaptureQuickStatus(str, Enum):
    normal = "normal"
    abnormal = "abnormal"
    undecided = "undecided"


class CaptureReviewStatus(str, Enum):
    pending = "pending"
    confirmed = "confirmed"


class CaptureMediaType(str, Enum):
    photo = "photo"
    audio = "audio"


class CapturePartTag(str, Enum):
    crest = "crest"
    upstream_face = "upstream_face"
    downstream_face = "downstream_face"
    spillway = "spillway"
    outlet_structure = "outlet_structure"
    management_facility = "management_facility"
    surroundings = "surroundings"
    other = "other"


class StructureCategory(str, Enum):
    water_retaining = "water_retaining"
    water_releasing = "water_releasing"
    water_conveyance = "water_conveyance"
    power_generation = "power_generation"
    management = "management"
    environment = "environment"
    other = "other"


class StructureObjectType(str, Enum):
    main_dam = "main_dam"
    aux_dam = "aux_dam"
    spillway = "spillway"
    outlet_tunnel = "outlet_tunnel"
    spill_tunnel = "spill_tunnel"
    power_tunnel = "power_tunnel"
    admin_facility = "admin_facility"
    updownstream_env = "updownstream_env"
    custom = "custom"
