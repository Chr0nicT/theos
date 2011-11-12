package Logos::Generator::internal::Method;
use strict;
use Logos::Method;
our @ISA = ('Logos::Method');

sub classname {
	my $self = shift;
	return ($self->{SCOPE} eq "+" ? "meta\$" : "").$self->class->name;
}

sub new_selector {
	my $self = shift;
	if($self->numArgs == 0) {
		return $self->{SELECTOR_PARTS}[0];
	} else {
		return join("\$", @{$self->{SELECTOR_PARTS}})."\$";
	}
}

sub originalFunctionName {
	my $self = shift;
	return "_".$self->groupIdentifier."\$".$self->classname."\$".$self->new_selector;
}

sub newFunctionName {
	my $self = shift;
	return "\$".$self->groupIdentifier."\$".$self->classname."\$".$self->new_selector;
}

sub originalCallParams {
	my $self = shift;
	my $customargs = shift;
	return "" if $self->{NEW};

	my $build = "(self, _cmd";
	if(defined $customargs && $customargs ne "") {
		$build .= ", ".$customargs;
	} elsif($self->numArgs > 0) {
		$build .= ", ".join(", ",@{$self->{ARGNAMES}});
	}
	$build .= ")";
	return $build;
}

sub definition {
	my $self = shift;
	my $build = "";
	my $classargtype = "";
	my $classref = "";
	if($self->{SCOPE} eq "+") {
		$classargtype = "Class";
		$classref = $self->class->superMetaVariable;
	} else {
		$classargtype = $self->class->type;
		$classref = $self->class->superVariable;
	}
	my $arglist = "";
	map $arglist .= ", ".$self->{ARGTYPES}[$_]." ".$self->{ARGNAMES}[$_], (0..$self->numArgs - 1);
	if(!$self->{NEW}) {
		my $argtypelist = join(", ", @{$self->{ARGTYPES}});

		$build .= "static ".$self->{RETURN}." ".$self->originalFunctionName."_s(".$classargtype." self, SEL _cmd".$arglist.") {";
		$build .=     "return ((".$self->{RETURN}." (*)(".$classargtype.", SEL";
		$build .=         ", ".$argtypelist if $argtypelist;
		$build .=         "))class_getMethodImplementation(".$classref.", \@selector(".$self->selector.")))";
		$build .=         $self->originalCallParams.";";
		$build .= "}";
	
	}
	$build .= "static ".$self->{RETURN}." ".$self->newFunctionName."(".$classargtype." self, SEL _cmd".$arglist.")";
	return $build;
}

sub originalCall {
	my $self = shift;
	return $self->originalFunctionName.$self->originalCallParams;
}

sub declarations {
	my $self = shift;
	my $classargtype = "";
	if($self->{SCOPE} eq "+") {
		$classargtype = "Class";
	} else {
		$classargtype = $self->class->type;
	}
	my $build = "";
	$build .= "static ".$self->{RETURN}." (*".$self->originalFunctionName.")(".$classargtype.", SEL"; 
	my $argtypelist = join(", ", @{$self->{ARGTYPES}});
	$build .= ", ".$argtypelist if $argtypelist;
	$build .= ");";
	return $build;
}

sub initializers {
	my $self = shift;
	my $classvar = ($self->{SCOPE} eq "+" ? $self->class->metaVariable : $self->class->variable);
	my $r = "{ ";
	if(!$self->{NEW}) {
		my $classargtype = "";
		if($self->{SCOPE} eq "+") {
			$classargtype = "Class";
		} else {
			$classargtype = $self->class->type;
		}
		my $pointertype = $self->{RETURN}." (*)(".$classargtype.", SEL";
		my $argtypelist = join(", ", @{$self->{ARGTYPES}});
		$pointertype .= ", ".$argtypelist if $argtypelist;
		$pointertype .= ")";
		$r .= "Class _class = ".$classvar.";";
		$r .= "Method _method = class_getInstanceMethod(_class, \@selector(".$self->selector."));";
		$r .= "if (_method) {";
		$r .=     $self->originalFunctionName." = ".$self->originalFunctionName."_s;";
		$r .=     "if (!class_addMethod(_class, \@selector(".$self->selector."), (IMP)&".$self->newFunctionName.", method_getTypeEncoding(_method))) {";
		$r .=         $self->originalFunctionName." = (".$pointertype.")method_getImplementation(_method);";
		$r .=         $self->originalFunctionName." = (".$pointertype.")method_setImplementation(_method, (IMP)&".$self->newFunctionName.");";
		$r .=     "}";
		$r .= "}";
	} else {
		if(!$self->{TYPE}) {
			$r .= "char _typeEncoding[1024]; unsigned int i = 0; ";
			for ($self->{RETURN}, "id", "SEL", @{$self->{ARGTYPES}}) {
				my $typeEncoding = Logos::Method::typeEncodingForArgType($_);
				if(defined $typeEncoding) {
					my @typeEncodingBits = split(//, $typeEncoding);
					my $i = 0;
					for my $char (@typeEncodingBits) {
						$r .= "_typeEncoding[i".($i > 0 ? " + $i" : "")."] = '$char'; ";
						$i++;
					}
					$r .= "i += ".(scalar @typeEncodingBits)."; ";
				} else {
					$r .= "memcpy(_typeEncoding + i, \@encode($_), strlen(\@encode($_))); i += strlen(\@encode($_)); ";
				}
			}
			$r .= "_typeEncoding[i] = '\\0'; ";
		} else {
			$r .= "const char *_typeEncoding = \"".$self->{TYPE}."\"; ";
		}
		$r .= "class_addMethod(".$classvar.", \@selector(".$self->selector."), (IMP)&".$self->newFunctionName.", _typeEncoding); ";
	}
	$r .= "}";
	return $r;
}

1;
