# Tool catalog manifest

Regenerate from the Seekmodo monorepo when gateway tools change:

```bash
cd seekmodo.com/seekmodo
composer install -d services/mcp-gateway
php tools/export_tool_catalog.php --out=../seekmodo-ruby-sdk/docs/tool-catalog.json
php tools/export_tool_catalog.php --out=../seekmodo-go-sdk/docs/tool-catalog.json
```

The manifest drives SDK docs and optional codegen for `Tools::Registry` typed helpers.
