TEST_OPT=
ifdef seq
	TEST_OPT=--sequential
endif

all: test

clean:
	@rm -f bin/test testbin/checkenv testbin/hello

stub: testbin/hello testbin/checkenv

test: stub bin/test
	@bin/test --noprog $(TEST_OPT)

bin/test: $(wildcard pskit/*.pony) $(wildcard pskit/spawn/*.pony) $(wildcard pskit/spawn/test/*.pony)
	@ponyc -o bin -d pskit/spawn/test

testbin/checkenv: $(wildcard stub/checkenv/*.pony)
	@ponyc -o testbin -d stub/checkenv

testbin/hello: $(wildcard stub/hello/*.pony)
	@ponyc -o testbin -d stub/hello
