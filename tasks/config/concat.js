/**
 * Concatenate files.
 *
 * ---------------------------------------------------------------
 *
 * Concatenates files javascript and css from a defined array. Creates concatenated files in
 * .tmp/public/contact directory
 * [concat](https://github.com/gruntjs/grunt-contrib-concat)
 *
 * For usage docs see:
 * 		https://github.com/gruntjs/grunt-contrib-concat
 */
module.exports = function(grunt) {

	grunt.config.set('concat', {
    coffee: {
      options: {
        banner: "###!!!\n#! This file is autogenerated. To modify please change the appropriate file in\n" +
          "#! the js/api folder\n###\n\n\n"
      },
			src: ['assets/js/api/*.coffee', '!assets/js/api/dbAPI.coffee', '!assets/js/api/dexieScopes.coffee', 'assets/js/api/dexieScopes.coffee' ,'assets/js/api/dbAPI.coffee'],
			dest: 'assets/js/trackAPI.coffee'
		},
		css: {
			src: require('../pipeline').cssFilesToInject,
			dest: 'dist/concat/production.css'
		}
	});

	grunt.loadNpmTasks('grunt-contrib-concat');
};
