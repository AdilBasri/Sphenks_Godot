import os

file_path = 'final_oda.tscn'
with open(file_path, 'r', encoding='utf-8') as f:
    text = f.read()

wrap_target = '''[node name="canavar" parent="." index="2" instance=ExtResource("9_uc2wd")]
transform = Transform3D(1.55, 0, 0, 0, 1.55, 0, 0, 0, 1.55, 0, 0.06913066, 0)
script = ExtResource("13_canavr")'''

wrap_replacement = '''[node name="canavar" type="CharacterBody3D" parent="." index="2"]
script = ExtResource("13_canavr")
transform = Transform3D(1.55, 0, 0, 0, 1.55, 0, 0, 0, 1.55, 0, 0.06913066, 0)
collision_layer = 4
collision_mask = 3

[node name="CollisionShape3D" type="CollisionShape3D" parent="canavar" index="0"]
transform = Transform3D(0.645, 0, 0, 0, 0.645, 0, 0, 0, 0.645, 0, 0.9, 0)
shape = SubResource("CapsuleShape3D_cnvr1")

[node name="canavar_mesh" parent="canavar" index="1" instance=ExtResource("9_uc2wd")]'''

if wrap_target in text:
    text = text.replace(wrap_target, wrap_replacement)

    sub_res = '''[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_cnvr1"]
radius = 0.4
height = 1.8

[sub_resource type="BoxShape3D" id="BoxShape3D_re4p6"]'''

    text = text.replace('[sub_resource type="BoxShape3D" id="BoxShape3D_re4p6"]', sub_res)

    text = text.replace('parent="canavar/Armature"', 'parent="canavar/canavar_mesh/Armature"')
    text = text.replace('path="canavar"', 'path="canavar/canavar_mesh"')

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(text)
    print('Converted final_oda.tscn to CharacterBody3D successfully.')
else:
    print('Target node structure not found or already converted.')
