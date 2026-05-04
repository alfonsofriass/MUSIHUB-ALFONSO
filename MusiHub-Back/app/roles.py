from enum import Enum

class RoleCode(str, Enum):
    musico = "musico"
    venta = "venta"
    sala_bar = "sala_bar"
    academia_profesor = "academia_profesor"