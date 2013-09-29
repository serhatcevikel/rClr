testDir <- system.file('tests', package='rClr') 
stopifnot(file.exists(testDir))
source(file.path(testDir, 'load_libs.r'))

context("rClr wrappers using R references classes")

test_that("Object constructors calls work", {
  tName <- 'Rclr.TestObject'
  i1 <- as.integer(23) ; i2 <- as.integer(42) 
  d1 <- 1.234; d2 <- 2.345;
  obj <- clrNew(tName, i1)
  obj <- clrCobj(obj)
# > class(w)
# [1] "Rcpp_World"
# attr(,"package")
# [1] "rcppf"
# > 
  expect_equal(class(obj), tName)

  expect_equal( obj$FieldIntegerOne, i1 );
  obj <- clrNew(tName, i1, i2)
  expect_that( clrGet(obj, "FieldIntegerOne"), equals(i1) );
  expect_that( clrGet(obj, "FieldIntegerTwo"), equals(i2) );
  obj <- clrNew(tName, d1, d2)
  expect_that( clrGet(obj, "FieldDoubleOne"), equals(d1) );
  expect_that( clrGet(obj, "FieldDoubleTwo"), equals(d2) );
})

test_that("Basic types of length one are marshalled correctly", {
  expect_that( clrCallStatic(cTypename, "DoubleEquals", 123.0 ), is_true() );
  expect_that( clrCallStatic(cTypename, "CreateDouble"), equals(123.0) );
  expect_that( clrCallStatic(cTypename, "IntEquals", as.integer(123) ), is_true() );
  expect_that( clrCallStatic(cTypename, "CreateInt"), equals(as.integer(123)) );
  expect_that( clrCallStatic(cTypename, "StringEquals", 'ab' ), is_true() );
  expect_that( clrCallStatic(cTypename, "CreateString"), equals('ab') );
# TODO: test unicode characters: what is happening then
})

test_that("String arrays are marshalled correctly", {
  ltrs = paste(letters[1:5], letters[2:6], sep='')
  expect_that( clrCallStatic(cTypename, "StringArrayEquals", ltrs), is_true() );
  expect_that( clrCallStatic(cTypename, "CreateStringArray"), equals(ltrs) );
  
  ltrs[3] = NA
  # expect_that( clrCallStatic(cTypename, "CreateStringArrayMissingVal"), equals(ltrs) );
  # expect_that(clrCallStatic(cTypename, "StringArrayMissingValsEquals", ltrs), is_true() );
  
})

test_that("Numeric arrays are marshalled correctly", {
  expectedNumArray <- 1:5 * 1.1  
  expect_that( clrCallStatic(cTypename, "CreateNumArray"), equals(expectedNumArray) );
  ## Internally somewhere, some noise is added probably in a float to double conversion. 
  ## Expected, but 5e-8 is more difference than I'd have guessed. Some watch point.
  # expect_that( clrCallStatic(cTypename, "CreateFloatArray"), equals(expectedNumArray) );
  expect_equal( clrCallStatic(cTypename, "CreateFloatArray"), expected = expectedNumArray, tolerance = 5e-8, scale = expectedNumArray)
  expect_that( clrCallStatic(cTypename, "NumArrayEquals", expectedNumArray ), is_true() );

  numDays = 5
  expect_equal( clrCallStatic(cTypename, "CreateIntArray", as.integer(numDays)), expected = 0:(numDays-1))

  expectedNumArray[3] = NA
  expect_that( clrCallStatic(cTypename, "CreateNumArrayMissingVal"), equals(expectedNumArray) );
  expect_that( clrCallStatic(cTypename, "NumArrayMissingValsEquals", expectedNumArray ), is_true() );
    
})

test_that("Complex numbers do not crash things", {
  z = 1+2i
  # TODO 
  # clrType = clrCallStatic('Rclr.ClrFacade', 'GetObjectTypeName', z)
  # expect_that( clrType, equals('What??') );
})

# TODO: test that passing an S4 object that is not a clr object converts to a null reference in the CLR


test_that("Correct method binding based on parameter types", {
  mkArrayTypeName <- function(typeName) { paste(typeName, '[]', sep='') }
  f <- function(...){ clrCallStatic('Rclr.TestMethodBinding', 'SomeStaticMethod', ...) }
  printIfDifferent <- function( got, expected ) { if(any(got != expected)) {print( paste( "got", got, ", expected", expected))} }
  g <- function(values, typeName) {
    if(is.list(values)) { # this is what one gets with a concatenation of S4 objects, when we use c(testObj,testObj) with CLR objects
      printIfDifferent( f(values[[1]]), typeName)
      printIfDifferent( f(values), mkArrayTypeName(typeName)) # This is not yet supported?
      printIfDifferent( f(values[[1]], values[[2]]), rep(typeName, 2))
      expect_equal( f(values[[1]]), typeName)
      expect_equal( f(values), mkArrayTypeName(typeName))
      expect_equal( f(values[[1]], values[[2]]), rep(typeName, 2))
    } else {
      printIfDifferent( f(values[1]), typeName)
      printIfDifferent( f(values), mkArrayTypeName(typeName))
      printIfDifferent( f(values[1], values[2]), rep(typeName, 2))
      expect_equal( f(values[1]), typeName)
      expect_equal( f(values), mkArrayTypeName(typeName))
      expect_equal( f(values[1], values[2]), rep(typeName, 2))
    }
  }
  intName <- 'System.Int32'
  doubleName <- 'System.Double'
  stringName <- 'System.String'
  boolName <- 'System.Boolean'
  dateTimeName <- 'System.DateTime'
  objectName <- 'System.Object'
  testObj <- clrNew(testClassName)
  
  testMethodBinding <- function() {
    g(1:3, intName)
    g(1.2*1:3, doubleName)
    g(letters[1:3], stringName)
    g(rep(TRUE,3), boolName)
    g(as.Date('2001-01-01') + 1:3, dateTimeName)
    g(c(testObj,testObj,testObj), objectName )

    expect_equal( f(1.0, 'a'), c(doubleName, stringName))
    expect_equal( f(1.0, 'a', 'b'), c(doubleName, stringName, stringName))
    expect_equal( f(1.0, letters[1:2]), c(doubleName, mkArrayTypeName(stringName)))
    expect_equal( f(1.0, letters[1:10]), c(doubleName, mkArrayTypeName(stringName)))
    
    expect_equal( f('a', letters[1:3]), c(stringName, mkArrayTypeName(stringName)) )
    expect_equal( f(letters[1:3], 'a'), c(mkArrayTypeName(stringName), stringName) )
    expect_equal( f(letters[1:3], letters[4:6]), c(mkArrayTypeName(stringName), mkArrayTypeName(stringName)) )
  }  
  testMethodBinding()
  obj <- clrNew('Rclr.TestMethodBinding')
  f <- function(...){ clrCall(obj, 'SomeInstanceMethod', ...) }
  testMethodBinding()
  # Test that methods implemented to comply with an interface are found, even if the method is explicitely implemented.
  # We do not want the users to have to figure out which interface type they deal with, at least not for R users.
  f <- function(...){ clrCall(obj, 'SomeExplicitlyImplementedMethod', ...) }
  testMethodBinding()
})


test_that("Numerical bi-dimensional arrays are marshalled correctly", {
  numericMat = matrix(as.numeric(1:15), nrow=3, ncol=5, byrow=TRUE)
  # A natural marshalling of jagged arrays is debatable. For the time being assuming that they are matrices, due to the concrete use case.
  expect_that( clrCallStatic(cTypename, "CreateJaggedFloatArray"), equals(numericMat));
  expect_that( clrCallStatic(cTypename, "CreateJaggedDoubleArray"), equals(numericMat));
  expect_that( clrCallStatic(cTypename, "CreateRectFloatArray"), equals(numericMat));
  expect_that( clrCallStatic(cTypename, "CreateRectDoubleArray"), equals(numericMat));

  # expect_that( clrCallStatic(cTypename, "NumericMatrixEquals", numericMat), equals(numericMat));

})

test_that("CLI dictionaries are marshalled as expected", {
  # The definition of 'as expected' for these collections is not all that clear, and there may be some RDotNet limitations.
  expect_that( clrCallStatic(cTypename, "CreateStringDictionary"), equals(c(a='A', b='B')));
})

test_that("Basic objects are created correctly", {
  testObj = clrNew(testClassName)
  expect_that( testObj@clrtype, equals(testClassName))
  rm(testObj)
	extptr <-.External("r_call_static_method", cTypename, "CreateTestObject",PACKAGE=clrGetNativeLibName())
  expect_that(is.null(extptr), is_false())
  expect_that("externalptr" %in% class(extptr), is_true())
  expect_that(clrTypeNameExtPtr(extptr), equals(testClassName))
})

test_that("Object members discovery behaves as expected", {
  expect_that(all(c('ClrFacade', 'mscorlib') %in% clrGetLoadedAssemblies()), is_true())
  expect_that('Rclr.TestObject' %in% clrGetTypesInAssembly('ClrFacade'), is_true())
  testObj = clrNew(testClassName)
  members = clrReflect(testObj)

  f<- function(obj_or_tname, static=FALSE, getF, getP, getM) { # copy-paste may have been more readable... Anyway.
    prefix <- ifelse(static, 'Static', '') 
    collate <- function(...) {paste(..., sep='')} # surely in stringr, but avoid dependency
    p <- function(basefieldname) {collate(prefix, basefieldname)}

    expect_that(getF(obj_or_tname, 'IntegerOne'), equals(p('FieldIntegerOne')))
    expect_that(getP(obj_or_tname, 'IntegerOne'), equals(p('PropertyIntegerOne')))

    expected_mnames <- paste(c('get_','','set_'), p(c('PropertyIntegerOne', "GetFieldIntegerOne", "PropertyIntegerOne")), sep='')
    actual_mnames <- getM(obj_or_tname, 'IntegerOne')

    expect_that( length(actual_mnames), equals(length(expected_mnames)))
    expect_that( all( actual_mnames %in% expected_mnames), is_true())

    sig_prefix = ifelse(static, 'Static, ', '')
    expect_that(clrGetMemberSignature(obj_or_tname, p('GetFieldIntegerOne')), 
      equals(collate(sig_prefix, "Method: Int32 ", p("GetFieldIntegerOne"))))
    expect_that(clrGetMemberSignature(obj_or_tname, p('GetMethodWithParameters')), 
      equals(collate(sig_prefix, "Method: Int32 ", p("GetMethodWithParameters, Int32, String"))))
  }
  f(testObj, static=FALSE, clrGetFields, clrGetProperties, clrGetMethods)
  f(testClassName, static=TRUE, clrGetStaticFields, clrGetStaticProperties, clrGetStaticMethods)
  # TODO test that methods that are explicit implementations of interfaces are found
})

test_that("Retrieval of object or class (i.e. static) members values behaves as expected", {
  f <- function(obj_or_type, rootMemberName, staticPrefix='') {
    fieldName <- paste(staticPrefix, 'Field', rootMemberName, sep='')
    propName <- paste(staticPrefix, 'Property', rootMemberName, sep='')
    clrSet(obj_or_type, fieldName, as.integer(0))
    expect_that(clrGet(obj_or_type, fieldName), equals(0))
    clrSet(obj_or_type, fieldName, as.integer(2))
    expect_that(clrGet(obj_or_type, fieldName), equals(2))
    clrSet(obj_or_type, propName, as.integer(0))
    expect_that(clrGet(obj_or_type, propName), equals(0))
    clrSet(obj_or_type, propName, as.integer(2))
    expect_that(clrGet(obj_or_type, propName), equals(2))
  }
  # first object members
  testObj = clrNew(testClassName)
  f(testObj, 'IntegerOne', staticPrefix='')
  # then test static members
  f(testClassName, 'IntegerOne', staticPrefix='Static')
})

test_that("enums get/set", {
  # very basic support for the time being. Behavior to be defined for cases such as enums with binary operators ([FlagsAttribute]) 
  eType <- 'Rclr.TestEnum'
  expect_that(clrGetEnumNames(eType), equals(c('A','B','C')))  
#  TODO, but problematic.
#  e <- clrCall(cTypename, 'GetTestEnum', 'B')
#  expect_false(is.null(e))  
#  expect_that(clrCall(e, 'ToString'), equals('B'))  
})

testGarbageCollection <- function( getObjCountMethodName = 'GetMemTestObjCounter', createTestObjectMethodName = 'CreateMemTestObj')
{
  callGcMethname <- "CallGC"

  counter = clrCallStatic(cTypename, getObjCountMethodName)
  expect_that( counter, equals(0) ); # make sure none of these test objects instances are hanging in the CLR
  testObj = clrCallStatic(cTypename, createTestObjectMethodName)
  expect_that( clrCallStatic(cTypename, getObjCountMethodName), equals(counter+1) );
  clrCallStatic(cTypename, callGcMethname)
  # the object should still be in memory.
  expect_that( clrCallStatic(cTypename, getObjCountMethodName), equals(counter+1) );
  gc()
  # the object should still be in memory, since testObj is in use and thus the underlying clr handle should be pinned too.
  expect_that( clrCallStatic(cTypename, getObjCountMethodName), equals(counter+1) );
  rm(testObj)
  gc()
  clrCallStatic(cTypename, callGcMethname)
  expect_that( clrCallStatic(cTypename, getObjCountMethodName), equals(counter) ); 
}

test_that("Garbage collection in R and the CLR behaves as expected", {
  testGarbageCollection( getObjCountMethodName = 'GetMemTestObjCounter', createTestObjectMethodName = 'CreateMemTestObj')
})

test_that("Garbage collection of R.NET objects", {
  # Unfortunately cannot test this yet because of http://r2clr.codeplex.com/workitem/30
  # testGarbageCollection( getObjCountMethodName = 'GetMemTestObjCounterRDotnet', createTestObjectMethodName = 'CreateMemTestObjRDotnet')
})


test_that("Assembly loading", {
  # following not supported on Mono
  # clrLoadAssembly("System.Windows.Presentation, Version=3.5.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089")
  clrLoadAssembly('System.Net.Http, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
  
  # The use of partial assembly names is discouraged; nevertheless it is supported
  clrLoadAssembly("System.Web.Services")
})