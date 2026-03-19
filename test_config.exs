config_file = "WORKFLOW_FEISHU_ASCII.md"
yaml_content = File.read!(config_file)

# Parse YAML (simple split approach)
[yaml_front_matter, _] = String.split(yaml_content, "---", parts: 2)
IO.puts("YAML front matter:")
IO.puts(String.slice(yaml_front_matter, 0, 500))

# Check if lifecycle.enabled is present
if String.contains?(yaml_front_matter, "lifecycle:") do
  if String.contains?(yaml_front_matter, "enabled: true") do
    IO.puts("\n✓ Found lifecycle: enabled: true")
  else
    IO.puts("\n✗ lifecycle: enabled is NOT set to true")
  end
else
  IO.puts("\n✗ No lifecycle: section found")
end
