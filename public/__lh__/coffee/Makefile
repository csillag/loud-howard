default: uglify

clean:
	rm -f *.js

compile: clean
	coffee -c *.coffee

uglify: compile
	uglifyjs wait_indicator.js services.js directives.js filters.js controllers.js -c -m  > app.min.js

