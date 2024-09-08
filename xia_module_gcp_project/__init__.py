from xia_module_gcp_project.project import Project
from xia_module_gcp_project.organization import Organization
from xia_module_gcp_project.admin import Admin

modules = {
    "gcp-module-project": "Project",
    "gcp-module-organization": "Organization",
    "gcp-module-admin": "Admin",
}

__all__ = [
    "Project",
    "Organization",
    "Admin"
]

__version__ = "0.0.30"
