import os
import re
import glob

def process_tscn(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Change font path globally
    content = re.sub(r'(path="res://.*?)PressStart2P-Regular\.ttf(")', r'path="res://Assets/Fonts/Stencil Intellecta Trash Free.ttf"', content)
    content = re.sub(r'(path="res://.*?)Retro Shine\.ttf(")', r'path="res://Assets/Fonts/Stencil Intellecta Trash Free.ttf"', content)

    # Split into node blocks based on newline followed by bracket
    # Note: strings inside quotes might contain \n[, but Godot multiline strings are rare for those exact characters.
    # We will use a safe regex that finds Godot chunks
    blocks_raw = ('\n' + content).split('\n[')
    blocks = []
    for b in blocks_raw:
        if not b.strip(): continue
        blocks.append('[' + b)

    label_settings = {}
    new_blocks = []

    # Collect LabelSettings
    for b in blocks:
        if b.startswith('[sub_resource type="LabelSettings"'):
            id_match = re.search(r'id="([^"]+)"', b)
            if id_match:
                resource_id = id_match.group(1)
                props = {}
                for line in b.split('\n')[1:]:
                    if '=' in line:
                        k, v = line.split('=', 1)
                        props[k.strip()] = v.strip()
                label_settings[resource_id] = props
                
    # Modify Labels
    for b in blocks:
        if b.startswith('[node') and ('type="Label"' in b):
            b = b.replace('type="Label"', 'type="RichTextLabel"')
            lines = b.split('\n')
            header = lines[0]
            props = {}
            prop_order = []
            
            current_k = None
            for line in lines[1:]:
                if not line.strip(): continue
                # Parse key value pairs
                if '=' in line and not line.startswith(' ') and not line.startswith('\t') and not '=' not in line.split('"', 1)[0]:
                    k, v = line.split('=', 1)
                    current_k = k.strip()
                    props[current_k] = v.strip()
                    prop_order.append(current_k)
                elif current_k:
                    # Append multiline strings
                    props[current_k] += '\n' + line
                    
            settings_id = None
            if 'label_settings' in props:
                match = re.search(r'SubResource\("([^"]+)"\)', props['label_settings'])
                if match: settings_id = match.group(1)
                del props['label_settings']
                prop_order.remove('label_settings')
                
            custom_theme_overrides = []
            
            if settings_id and settings_id in label_settings:
                s = label_settings[settings_id]
                if 'font' in s: custom_theme_overrides.append(('theme_override_fonts/normal_font', s['font']))
                if 'font_size' in s: custom_theme_overrides.append(('theme_override_font_sizes/normal_font_size', s['font_size']))
                if 'font_color' in s: custom_theme_overrides.append(('theme_override_colors/default_color', s['font_color']))
                if 'outline_size' in s: custom_theme_overrides.append(('theme_override_constants/outline_size', s['outline_size']))
                if 'outline_color' in s: custom_theme_overrides.append(('theme_override_colors/font_outline_color', s['outline_color']))
                if 'shadow_color' in s: custom_theme_overrides.append(('theme_override_colors/font_shadow_color', s['shadow_color']))
                if 'shadow_offset' in s:
                    vec_match = re.search(r'Vector2\(([^,]+),\s*([^\)]+)\)', s['shadow_offset'])
                    if vec_match:
                        custom_theme_overrides.append(('theme_override_constants/shadow_offset_x', vec_match.group(1).strip()))
                        custom_theme_overrides.append(('theme_override_constants/shadow_offset_y', vec_match.group(2).strip()))
                if 'shadow_size' in s: custom_theme_overrides.append(('theme_override_constants/shadow_outline_size', s['shadow_size']))
                
            removals = []
            h_align = props.get('horizontal_alignment', "0")
            v_align = props.get('vertical_alignment', "0")
            
            for k, v in list(props.items()):
                if k == 'theme_override_fonts/font':
                    custom_theme_overrides.append(('theme_override_fonts/normal_font', v))
                    removals.append(k)
                elif k == 'theme_override_font_sizes/font_size':
                    custom_theme_overrides.append(('theme_override_font_sizes/normal_font_size', v))
                    removals.append(k)
                elif k == 'theme_override_colors/font_color':
                    custom_theme_overrides.append(('theme_override_colors/default_color', v))
                    removals.append(k)
                elif k in ['horizontal_alignment', 'vertical_alignment', 'autowrap_mode', 'clip_text', 'text_overrun_behavior']:
                    removals.append(k)
                    
            for rm in removals:
                if rm in props: del props[rm]
                if rm in prop_order: prop_order.remove(rm)
                
            text_val = props.get('text', "")
            if text_val.startswith('"') and text_val.endswith('"'):
                inner_text = text_val[1:-1]
                if inner_text != "":
                    if h_align == "1": inner_text = f"[center]{inner_text}[/center]"
                    elif h_align == "2": inner_text = f"[right]{inner_text}[/right]"
                    props['text'] = f'"{inner_text}"'
            elif text_val.startswith('"""') and text_val.endswith('"""'):
                inner_text = text_val[3:-3]
                if inner_text.strip() != "":
                    if h_align == "1": inner_text = f"[center]{inner_text}[/center]"
                    elif h_align == "2": inner_text = f"[right]{inner_text}[/right]"
                    props['text'] = f'"""{inner_text}"""'
            
            new_b = [header]
            added_bbcode = False
            for k in prop_order:
                if k == 'text':
                    new_b.append("bbcode_enabled = true")
                    new_b.append("fit_content = true")
                    new_b.append("scroll_active = false")
                    added_bbcode = True
                new_b.append(f"{k} = {props[k]}")
                
            if not added_bbcode:
                new_b.append("bbcode_enabled = true")
                new_b.append("fit_content = true")
                new_b.append("scroll_active = false")
                
            for k, v in custom_theme_overrides:
                new_b.append(f"{k} = {v}")
                
            b = "\n".join(new_b) + "\n"
        new_blocks.append(b)
        
    final_text = "".join(new_blocks)
    if final_text != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(final_text)
            print(f"Updated {filepath}")

if __name__ == "__main__":
    files = glob.glob("**/*.tscn", recursive=True)
    count = 0
    for f in files:
        try:
            process_tscn(f)
            count += 1
        except Exception as e:
            print(f"Error processing {f}: {e}")
    print(f"Processed {count} tscn files.")
