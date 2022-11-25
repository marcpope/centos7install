[//lasso
	/*
	[Image] type for Lasso 8.x
	
	This is a drop-in replacement for the native [Image] type in Lasso 8.x. This version requires
	[OS_Process] and calls the ImageMagick command line utilities rather than relying on the 
	low-level libraries. Doing so eliminates the need to install an older version of ImageMagick and
	its dependencies on the server for compatibility. It is recommended that the ImageMagick module
	be removed from LassoModules when using this replacement to avoid startup errors.
	
	Known Issues:
	
		- Paths to binary executables on *nix systems are hard coded to default locations and may not match yours.
		- Some methods are not yet implemented. See list below.
		- The -info keyword is not implemented.
		- Parsing of identify data is fairly crude.
		- Passing null to [Image->AddComment] doesn't remove the comment.
		- The -top value provided to [Image->Annotate] offsets the *baseline* of the text.
		- ImageMagick requires radius and sigma for motion blurs, but Lasso's API doesn't, so for compatibility, default values are provided.
		- The default brightness, saturation, and hue values for [Image->Modulate] should be given as 100 (per the IM docs) vs. 0 (per the Lasso docs).
	
	The following methods are not yet implemented:

		[Image->Composite]
		[Image->Execute]
	*/

	// log_detail('Loading replacement [image] type.');
	// lasso_tagexists('image') ? log_detail('Built-in [image] type is loaded, but should be removed.');
	// !lasso_tagexists('os_process') ? log_critical('Non-native [image] type requires [os_process], which is not loaded.');

	define_type(
		'image',
		-prototype,
		-description='Drop-in replacement for the built-in [Image] type.'
	);
		local(
			'filepath' = null,
			'data' = null,
			'metadata' = map,
			'describe' = string,
			'platform' = string,
			'path' = '/usr/local/bin',
			'debug'
		);
		
		
		define_tag(
			'oncreate',
			-opt='filepath', -type='string',
			-opt='binary', -type='bytes',
			-opt='base64', -type='string',
			-opt='info',
			-encodenone
		);		
			// get image data
			if(local_defined('base64'));
				self->'data' = decode_base64(#base64);
			else(local_defined('binary'));
				self->'data' = #binary;
			else(local_defined('filepath'));
				// TODO: handle -info parameter to avoid loading large files into memory
				self->'filepath' = #filepath;
				self->'data' = file_read(#filepath);
			else;
				fail( -9996, 'Image type initializer requires at least one parameter (filepath, image type, or image data)');
			/if;
			
			local('platform') = lasso_version( -lassoplatform);
			self->'platform' = #platform;
			
			if(#platform >> 'Lin');
				self->'path' = '/usr/bin/';
			else(#platform >> 'Mac');
				self->'path' = '/usr/local/bin/';
			else(#platform >> 'Win');
				local('os') = os_process('cmd', array('/c','where','identify'));
				local('path') = string(#os->read);
				#os->close;
				#path->trim&removetrailing('identify.exe');
				self->'path' = #path;
			/if;
			
			self->identify;
		/define_tag;


		// This allows us to access all of the individual
		// metadata properties via member tags, e.g., ->width,
		// ->format, etc.
		// However, this means if we're not accessing metadata,
		// we will need an explicit getter.
		define_tag('_unknowntag', -encodenone);
			local('property') = self->'metadata'->find(tag_name);
			return(#property);
		/define_tag;		
				
		
		define_tag(
			'_process',
			-req='cmd', -type='string', -copy,
			-req='args', -type='array', -copy,
			-encodenone
		);
			self->'platform' >> 'Win' ? #cmd += '.exe';
			// self->'debug' += 'Command: ' + #cmd + ' ' + #args->join(' ') + '\n';
			local('os') = os_process(#cmd, #args);		
			#os->write(self->'data');
			#os->closewrite;
			local('response') = #os->read;
			local('error') = #os->readerror;
			#os->close;			
			fail_if(!#response, -1, #error);
			// self->'debug' += 'stdout: ' + #response + '\n';			
			// self->'debug' += 'stderr: ' + #error + '\n';			
			self->'data' = #response;			
			self->identify;			
		/define_tag;


		define_tag(
			'addcomment',
			-req='comment', -copy
		);	
			#comment == null ? #comment = '';
			local('operation') = '-set';
			
			local(
				'cmd' = self->'path' + 'convert',
				'args' = array(
					'-',
					#operation,
					'comment',
					#comment
				)
			);
			
			#args->insert('-');			
			self->_process(#cmd, #args);
		/define_tag;


		define_tag(
			'annotate',
			-req='left', -type='integer', -copy,
			-req='top', -type='integer', -copy,
			-opt='font', -type='string',
			-opt='size', -type='integer',
			-opt='color', -type='string'
		);	
			fail_if(!params->first->isa('string'), -9996, 'The first argument to [Image->Annotate] must be a string.');

			#left >= 0 ? #left = '+' + #left;
			#top >= 0 ? #top = '+' + #top;
			
			local(
				'text' = params->first,
				'geometry' = #left + #top,
				'operation' = '-annotate',
				'args' = array('-'),
				'cmd' = self->'path' + 'convert'
			);
			
			if(local_defined('font'));
				#args->insert('-font');
				#args->insert(#font);
			/if;
			
			if(local_defined('size'));
				#args->insert('-pointsize');
				#args->insert(#size);
			/if;

			if(local_defined('color'));
				#args->insert('-fill');
				#args->insert(#color);
			/if;
			
			params >> '-aliased' ? #args->insert('-antialias');
			
			#args->insert(#operation);
			#args->insert(#geometry);
			#args->insert(#text);			
			#args->insert('-');
			
			self->_process(#cmd, #args);
		/define_tag;


		define_tag(
			'blur',
			-opt='angle', -copy,
			-opt='radius', -copy,
			-opt='sigma', -copy
		);
			local_defined('angle') ? #angle = decimal(#angle);
			local_defined('radius') ? #radius = decimal(#radius);
			local_defined('sigma') ? #sigma = decimal(#sigma);
		
			local(
				'args' = array('-'),
				'cmd' = self->'path' + 'convert'
			);

			if(params >> '-gaussian');
				fail_if(!local_defined('radius') || !local_defined('sigma'), -9996, '[Image->Blur] requires -Radius and -Sigma values to perform a Gaussian blur.');
			
				#args->insert('-blur');
				#args->insert(#radius + 'x' + #sigma);
			else;
				fail_if(!local_defined('angle'), -9996, '[Image->Blur] requires an -Angle value unless performing a Gaussian blur.');
				
				// ImageMagick requires radius and sigma for motion blurs, but Lasso's API doesn't,
				// so for compatibility default values are provided.
				!local_defined('radius') ? local('radius') = 0;
				!local_defined('sigma') ? local('sigma') = 12;
				
				#angle >= 0 ? #angle = '+' + #angle;
				local('geometry') = #radius + 'x' + #sigma + #angle;
				
				#args->insert('-motion-blur');
				#args->insert(#geometry);
			/if;

			#args->insert('-');			
			self->_process(#cmd, #args);			
		/define_tag;
	

		define_tag('comments');
			return(self->'metadata'->find('comment'));
		/define_tag;


		define_tag('contrast');
			local(
				'cmd' = self->'path' + 'convert',
				'args' = array(
					'-',
					(params && params->first == null ? '+' | '-') + 'contrast',
					'-'
				)
			);
			
			self->_process(#cmd, #args);			
		/define_tag;


		define_tag(
			'convert',
			-req='format', -type='string',
			-opt='quality', -type='integer',
			-encodenone
		);
			fail_if(local_defined('quality') && (#quality < 0 || #quality > 1000), -1, 'Value of -quality parameter must be between 0 and 1000.');
			
			local(
				'cmd' = self->'path' + 'convert',
				'args' = array(
					'-',
					'-format',
					'"' + #format + '"'
				)
			);
			
			local_defined('quality') ? #args->insert('-quality')&insert(#quality);
			#args->insert('-');			
			self->_process(#cmd, #args);
		/define_tag;


		define_tag(
			'crop',
			-req='width', -type='integer',
			-req='height', -type='integer',
			-req='left', -type='integer', -copy,
			-req='top', -type='integer', -copy
		);	
			#left >= 0 ? #left = '+' + #left;
			#top >= 0 ? #top = '+' + #top;
			local('geometry') = #width + 'x' + #height + #left + #top;			
			local('operation') = '-crop';
			
			local(
				'cmd' = self->'path' + 'convert',
				'args' = array(
					'-',
					#operation,
					#geometry,
					'+repage'
				)
			);
			
			#args->insert('-');			
			self->_process(#cmd, #args);
		/define_tag;


		define_tag('data', -encodenone);
			return(self->'data');
		/define_tag;
		
		
		define_tag('describe', -encodenone);
			return(self->'describe');
		/define_tag;


		define_tag('enhance');
			local(
				'cmd' = self->'path' + 'convert',
				'args' = array('-', '-enhance', '-')
			);
			
			self->_process(#cmd, #args);			
		/define_tag;
		

		define_tag('file');
			return(self->'filepath');
		/define_tag;


		define_tag('fliph');
			local(
				'cmd' = self->'path' + 'convert',
				'args' = array('-', '-flop', '-')
			);
			
			self->_process(#cmd, #args);			
		/define_tag;


		define_tag('flipv');
			local(
				'cmd' = self->'path' + 'convert',
				'args' = array('-', '-flip', '-')
			);
			
			self->_process(#cmd, #args);			
		/define_tag;


		define_tag('histogram');
			local(
				'cmd' = self->'path' + 'convert',
				'args' = array(
					'-',
					'-format',
					'%c',
					'histogram:info:-'
				)
			);
			
			local('os') = os_process(#cmd, #args);		
			#os->write(self->'data');
			#os->closewrite;
			local('response') = #os->read;
			local('error') = #os->readerror;
			#os->close;			
			fail_if(!#response, -1, #error);
			return(#response);			
		/define_tag;

		
		define_tag('identify');
			local(
				'cmd' = self->'path' + 'identify',
				'args' = array('-verbose', '-')
			);

			self->'platform' >> 'Win' ? #cmd += '.exe';
			// self->'debug' += 'Command: ' + #cmd + ' ' + #args->join(' ') + '\n';
			local('os') = os_process(#cmd, #args);
			#os->write(self->'data');
			#os->closewrite;
			local('response') = #os->read;
			local('error') = #os->readerror;
			#os->close;
			
			fail_if(!#response, -1, #error);
			// self->'debug' += 'stdout: ' + #response + '\n';			
			// self->'debug' += 'stderr: ' + #error + '\n';			
			self->'describe' = #response;
			local('lines') = #response->split('\n');
			
			iterate(#lines, local('i'));
				local(
					'name' = #i->split(':')->first->trim&,
					'value' = string(#i)->trim&removeleading(#name + ': ')&
				);
				
				if(#name == 'Geometry');
					local(
						'width' = integer(#value->split('x')->first),
						'height' = integer(#value->split('x')->second->split('+')->first)
					);
					
					self->'metadata'->insert('width' = #width);
					self->'metadata'->insert('height' = #height);
				/if;
				
				#name && #value ? self->'metadata'->insert(#name = #value);
			/iterate;
		/define_tag;


		define_tag(
			'modulate',
			-req='brightness', -type='integer',
			-req='saturation', -type='integer',
			-req='hue', -type='integer'
		);
			local(
				'cmd' = self->'path' + 'convert',
				'args' = array(
					'-',
					'-modulate',
					#brightness + ',' + #saturation + ',' + #hue,
					'-'
				)
			);
			
			self->_process(#cmd, #args);			
		/define_tag;


		define_tag(
			'pixel',
			-req='left', -type='integer',
			-req='top', -type='integer'
		);
			local(
				'cmd' = self->'path' + 'convert',
				'args' = array(
					'-[1x1+' + #left + '+' + #top + ']',
					'txt:-'
				)
			);
			
			local('os') = os_process(#cmd, #args);		
			#os->write(self->'data');
			#os->closewrite;
			local('response') = #os->read;
			local('error') = #os->readerror;
			#os->close;			
			fail_if(!#response, -1, #error);
						
			if(params >> '-hex');
				local('hex') = string_findregexp(
					#response,
					-find='#(?:[0-9a-fA-F]{3}){1,2}',
					-ignorecase
				)->first;
				
				return(#hex);
			else;
				local('rgb') = string_findregexp(
					#response,
					-find='s?rgb\\(([0-9,]{5,11})\\)',
					-ignorecase
				)->second->split(',');
				
				return(#rgb);
			/if;		
		/define_tag;


		define_tag('resolutionh');
			return(integer(string(self->'metadata'->find('Resolution'))->split('x')->first));
		/define_tag;
		
		
		define_tag('resolutionv');
			return(integer(string(self->'metadata'->find('Resolution'))->split('x')->second));
		/define_tag;
		

		define_tag(
			'rotate',
			-opt='bgcolor', -type='string'
		);
			fail_if(
				!params || !params->first->isa('integer') || params->first < 0 || params->first > 360, 
				-9996, 'The first argument to [Image->Rotate] must be an integer value between 0 and 360.'
			);
			
			local(
				'degrees' = params->first,
				'cmd' = self->'path' + 'convert',
				'args' = array('-')
			);
			
			if(local_defined('bgcolor'));
				#args->insert('-background');
				#args->insert(#bgcolor);
			/if;
			
			#args->insert('-rotate');
			#args->insert(#degrees);
			#args->insert('-');
			
			self->_process(#cmd, #args);			
		/define_tag;
		

		define_tag(
			'save',
			-req='filepath', -type='string',
			-opt='quality', -type='integer'
		);
			local('format') = #filepath->split('.')->last;
			local_defined('quality') ? self->convert( -format=#format, -quality=#quality) | self->convert( -format=#format);
			file_write(#filepath, self->'data', -fileoverwrite);
		/define_tag;

		
		define_tag(
			'scale',
			-opt='width',
			-opt='height',
			-opt='sample',
			-opt='thumbnail'
		);
			fail_if(!local_defined('width') && !local_defined('height'), -1, '[Image->Scale] requires at least one dimension.');
			
			!local_defined('width') ? local('width') = '';
			!local_defined('height') ? local('height') = '';
			local('geometry') = #width + 'x' + #height;
			#geometry->removetrailing('x');
			
			local('operation') = '-scale';
			params >> '-sample' ? #operation = '-sample';
			params >> '-thumbnail' ? #operation = '-thumbnail';
			
			local(
				'cmd' = self->'path' + 'convert',
				'args' = array(
					'-',
					#operation,
					#geometry
				)
			);
			
			params >> '-thumbnail' ? #args->insert('-strip');
			#args->insert('-');			
			self->_process(#cmd, #args);
		/define_tag;


		define_tag(
			'setcolorspace',
			-opt='rgb',
			-opt='cmyk',
			-opt='gray'
		);
			fail_if(!params->size, -1, '[Image->SetColorSpace] requires at least one parameter, either -rgb, -cmyk, or -gray.');
			
			local('colorspace') = '';
			params >> '-rgb' ? #colorspace = 'RGB';
			params >> '-cmyk' ? #colorspace = 'CMYK';
			params >> '-gray' ? #colorspace = 'GRAY';
			
			local(
				'cmd' = self->'path' + 'convert',
				'args' = array(
					'-',
					'-colorspace',
					#colorspace,
					'-'
				)
			);
			
			self->_process(#cmd, #args);
		/define_tag;
		
		
		define_tag(
			'sharpen',
			-req='radius', -type='integer', -copy,
			-req='sigma', -type='integer', -copy,
			-opt='amount', -copy,
			-opt='threshold', -copy
		);			
			local('geometry') = #radius + 'x' + #sigma;
			
			if(local_defined('amount') && local_defined('threshold'));
				#amount = decimal(#amount);
				#amount >= 0 ? #amount = '+' + #amount;
				#threshold = decimal(#threshold);
				#threshold >= 0 ? #threshold = '+' + #threshold;
				#geometry += #amount + #threshold;
			/if;
			
			local(
				'cmd' = self->'path' + 'convert',
				'args' = array(
					'-',
					'-unsharp',
					#geometry,
					'-'
				)
			);
			
			self->_process(#cmd, #args);
		/define_tag;	
	/define_type;
]
