--
-- make_csharp.lua
-- Generate a C# project makefile.
-- Copyright (c) 2002-2013 Jess Perkins and the Premake project
--

	local p = premake
	p.makelegacy.cs = {}
	local make = p.makelegacy
	local cs = p.makelegacy.cs
	local project = p.project
	local config = p.config
	local fileconfig = p.fileconfig


--
-- Add namespace for element definition lists for p.callarray()
--

	cs.elements = {}


--
-- Generate a GNU make C++ project makefile, with support for the new platforms API.
--

	cs.elements.makefile = function(prj)
		return {
			make.header,
			make.phonyRules,
			make.csConfigs,
			make.csProjectConfig,
			make.csSources,
			make.csEmbedFiles,
			make.csCopyFiles,
			make.csResponseFile,
			make.shellType,
			make.csAllRules,
			make.csTargetRules,
			make.targetDirRules,
			make.csResponseRules,
			make.objDirRules,
			make.csCleanRules,
			make.preBuildRules,
			make.preLinkRules,
			make.csFileRules,
		}
	end


--
-- Generate a GNU make C# project makefile, with support for the new platforms API.
--

	function make.cs.generate(prj)
		p.eol("\n")
		local toolset = p.tools.dotnet
		p.callArray(cs.elements.makefile, prj, toolset)
	end


--
-- Write out the settings for a particular configuration.
--

	cs.elements.configuration = function(cfg)
		return {
			make.csTools,
			make.target,
			make.objdir,
			make.csFlags,
			make.csLinkCmd,
			make.preBuildCmds,
			make.preLinkCmds,
			make.postBuildCmds,
			make.settings,
		}
	end

	function make.csConfigs(prj, toolset)
		for cfg in project.eachconfig(prj) do
			_x('ifeq ($(config),%s)', cfg.shortname)
			p.callArray(cs.elements.configuration, cfg, toolset)
			_p('endif')
			_p('')
		end
	end


--
-- Given a .resx resource file, builds the path to corresponding .resource
-- file, matching the behavior and naming of Visual Studio.
--

	function cs.getresourcefilename(cfg, fname)
		if path.getextension(fname) == ".resx" then
			local name = cfg.buildtarget.basename .. "."
			local dir = path.getdirectory(fname)
			if dir ~= "." then
				name = name .. path.translate(dir, ".") .. "."
			end
			return "$(OBJDIR)/" .. p.esc(name .. path.getbasename(fname)) .. ".resources"
		else
			return fname
		end
	end


--
-- Iterate and output some selection of the source code files.
--

	function cs.listsources(prj, selector)
		local tr = project.getsourcetree(prj)
		p.tree.traverse(tr, {
			onleaf = function(node, depth)
				local value = selector(node)
				if value then
					_x('\t%s \\', value)
				end
			end
		})
	end





---------------------------------------------------------------------------
--
-- Handlers for individual makefile elements
--
---------------------------------------------------------------------------

	function make.csAllRules(prj, toolset)
		_p('all: $(TARGETDIR) $(OBJDIR) prebuild $(EMBEDFILES) $(COPYFILES) prelink $(TARGET)')
		_p('')
	end


	function make.csCleanRules(prj, toolset)
		--[[
		-- porting from 4.x
		_p('clean:')
		_p('\t@echo Cleaning %s', prj.name)
		_p('ifeq (posix,$(SHELLTYPE))')
		_p('\t$(SILENT) rm -f $(TARGETDIR)/%s.* $(COPYFILES)', target.basename)
		_p('\t$(SILENT) rm -rf $(OBJDIR)')
		_p('else')
		_p('\t$(SILENT) if exist $(subst /,\\\\,$(TARGETDIR)/%s) del $(subst /,\\\\,$(TARGETDIR)/%s.*)', target.name, target.basename)
		for target, source in pairs(cfgpairs[anycfg]) do
			_p('\t$(SILENT) if exist $(subst /,\\\\,%s) del $(subst /,\\\\,%s)', target, target)
		end
		for target, source in pairs(copypairs) do
			_p('\t$(SILENT) if exist $(subst /,\\\\,%s) del $(subst /,\\\\,%s)', target, target)
		end
		_p('\t$(SILENT) if exist $(subst /,\\\\,$(OBJDIR)) rmdir /s /q $(subst /,\\\\,$(OBJDIR))')
		_p('endif')
		_p('')
		--]]
	end


	function make.csCopyFiles(prj, toolset)
		--[[
		-- copied from 4.x; needs more porting
		_p('COPYFILES += \\')
		for target, source in pairs(cfgpairs[anycfg]) do
			_p('\t%s \\', target)
		end
		for target, source in pairs(copypairs) do
			_p('\t%s \\', target)
		end
		_p('')
		--]]
	end


	function make.cs.getresponsefilename(prj)
		return '$(OBJDIR)/' .. prj.filename .. '.rsp'
	end


	function make.csResponseFile(prj, toolset)
		_x('RESPONSE += ' .. make.cs.getresponsefilename(prj))
	end


	function make.csResponseRules(prj)
		local toolset = p.tools.dotnet
		local ext = make.getmakefilename(prj, true)
		local makefile = path.getname(p.filename(prj, ext))
		local response = make.cs.getresponsefilename(prj)

		_p('$(RESPONSE): %s', makefile)
		_p('\t@echo Generating response file', prj.name)

		_p('ifeq (posix,$(SHELLTYPE))')
			_x('\t$(SILENT) rm -f $(RESPONSE)')
		_p('else')
			_x('\t$(SILENT) if exist $(RESPONSE) del %s', path.translate(response, '\\'))
		_p('endif')

		local sep = os.istarget("windows") and "\\" or "/"
		local tr = project.getsourcetree(prj)
		p.tree.traverse(tr, {
			onleaf = function(node, depth)
				if toolset.fileinfo(node).action == "Compile" then
					_x('\t@echo %s >> $(RESPONSE)', path.translate(node.relpath, sep))
				end
			end
		})
		_p('')
	end


	function make.csEmbedFiles(prj, toolset)
		local cfg = project.getfirstconfig(prj)

		_p('EMBEDFILES += \\')
		cs.listsources(prj, function(node)
			local fcfg = fileconfig.getconfig(node, cfg)
			local info = toolset.fileinfo(fcfg)
			if info.action == "EmbeddedResource" then
				return cs.getresourcefilename(cfg, node.relpath)
			end
		end)
		_p('')
	end


	function make.csFileRules(prj, toolset)
		--[[
		-- porting from 4.x
		_p('# Per-configuration copied file rules')
		for cfg in p.eachconfig(prj) do
			_x('ifneq (,$(findstring %s,$(config)))', cfg.name:lower())
			for target, source in pairs(cfgpairs[cfg]) do
				p.makelegacy_copyrule(source, target)
			end
			_p('endif')
			_p('')
		end

		_p('# Copied file rules')
		for target, source in pairs(copypairs) do
			p.makelegacy_copyrule(source, target)
		end

		_p('# Embedded file rules')
		for _, fname in ipairs(embedded) do
			if path.getextension(fname) == ".resx" then
				_x('%s: %s', getresourcefilename(prj, fname), fname)
				_p('\t$(SILENT) $(RESGEN) $^ $@')
			end
			_p('')
		end
		--]]
	end


	function make.csFlags(cfg, toolset)
		_p('  FLAGS =%s', make.list(toolset.getflags(cfg)))
	end


	function make.csLinkCmd(cfg, toolset)
		local deps = p.esc(config.getlinks(cfg, "dependencies", "fullpath"))
		_p('  DEPENDS =%s', make.list(deps))
		_p('  REFERENCES = %s', table.implode(deps, "/r:", "", " "))
	end


	function make.csProjectConfig(prj, toolset)
		-- To maintain compatibility with Visual Studio, these values must
		-- be set on the project level, and not per-configuration.
		local cfg = project.getfirstconfig(prj)

		local kindflag = "/t:" .. toolset.getkind(cfg):lower()
		local libdirs = table.implode(p.esc(cfg.libdirs), "/lib:", "", " ")
		_p('FLAGS += %s', table.concat(table.join(kindflag, libdirs), " "))

		local refs = p.esc(config.getlinks(cfg, "system", "fullpath"))
		_p('REFERENCES += %s', table.implode(refs, "/r:", "", " "))
		_p('')
	end


	function make.csSources(prj, toolset)
		local cfg = project.getfirstconfig(prj)

		_p('SOURCES += \\')
		cs.listsources(prj, function(node)
			local fcfg = fileconfig.getconfig(node, cfg)
			local info = toolset.fileinfo(fcfg)
			if info.action == "Compile" then
				return node.relpath
			end
		end)
		_p('')
	end


	function make.csTargetRules(prj, toolset)
		_p('$(TARGET): $(SOURCES) $(EMBEDFILES) $(DEPENDS) $(RESPONSE)')
		_p('\t$(SILENT) $(CSC) /nologo /out:$@ $(FLAGS) $(REFERENCES) @$(RESPONSE) $(patsubst %%,/resource:%%,$(EMBEDFILES))')
		_p('\t$(POSTBUILDCMDS)')
		_p('')
	end


	function make.csTools(cfg, toolset)
		_p('  CSC = %s', toolset.gettoolname(cfg, "csc"))
		_p('  RESGEN = %s', toolset.gettoolname(cfg, "resgen"))
	end
