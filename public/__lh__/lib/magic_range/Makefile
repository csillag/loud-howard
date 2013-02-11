default: uglify

clean:
	rm -f *.js

compile: clean
	coffee -c *.coffee

uglify: compile
	uglifyjs *.js -c -m > magic.min.js

