// ignore_for_file: must_be_immutable
import 'package:authentication_client/authentication_client.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_authentication_client/firebase_authentication_client.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart'
    as facebook_auth;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:twitter_login/entity/auth_result.dart' as twitter_auth;
import 'package:twitter_login/twitter_login.dart' as twitter_auth;

class MockFirebaseAuth extends Mock implements firebase_auth.FirebaseAuth {}

class MockFirebaseUser extends Mock implements firebase_auth.User {}

class MockUserMetadata extends Mock implements firebase_auth.UserMetadata {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

@immutable
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {
  @override
  bool operator ==(dynamic other) => identical(this, other);

  @override
  int get hashCode => 0;
}

class MockGoogleSignInAuthentication extends Mock
    implements GoogleSignInAuthentication {}

class MockAuthorizationCredentialAppleID extends Mock
    implements AuthorizationCredentialAppleID {}

class MockFacebookAuth extends Mock implements facebook_auth.FacebookAuth {}

class MockFacebookLoginResult extends Mock
    implements facebook_auth.LoginResult {}

class MockFacebookAccessToken extends Mock
    implements facebook_auth.AccessToken {}

class MockUserCredential extends Mock implements firebase_auth.UserCredential {}

class FakeAuthCredential extends Fake implements firebase_auth.AuthCredential {}

class FakeActionCodeSettings extends Fake
    implements firebase_auth.ActionCodeSettings {}

class MockTwitterLogin extends Mock implements twitter_auth.TwitterLogin {}

class MockTwitterAuthResult extends Mock implements twitter_auth.AuthResult {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  MethodChannelFirebase.channel.setMockMethodCallHandler((call) async {
    if (call.method == 'Firebase#initializeCore') {
      return [
        {
          'name': defaultFirebaseAppName,
          'options': {
            'apiKey': '123',
            'appId': '123',
            'messagingSenderId': '123',
            'projectId': '123',
          },
          'pluginConstants': const <String, String>{},
        }
      ];
    }

    if (call.method == 'Firebase#initializeApp') {
      final arguments = call.arguments as Map<String, dynamic>;
      return <String, dynamic>{
        'name': arguments['appName'],
        'options': arguments['options'],
        'pluginConstants': const <String, String>{},
      };
    }

    return null;
  });

  TestWidgetsFlutterBinding.ensureInitialized();
  Firebase.initializeApp();

  const email = 'test@gmail.com';
  const emailLink = 'https://email.page.link';
  const password = 't0ps3cret42';
  const appPackageName = 'app.package.name';

  group('FirebaseAuthenticationClient', () {
    late firebase_auth.FirebaseAuth firebaseAuth;
    late GoogleSignIn googleSignIn;
    late FirebaseAuthenticationClient firebaseAuthenticationClient;
    late AuthorizationCredentialAppleID authorizationCredentialAppleID;
    late GetAppleCredentials getAppleCredentials;
    late List<List<AppleIDAuthorizationScopes>> getAppleCredentialsCalls;
    late facebook_auth.FacebookAuth facebookAuth;
    late twitter_auth.TwitterLogin twitterLogin;

    setUpAll(() {
      registerFallbackValue(FakeAuthCredential());
      registerFallbackValue(FakeActionCodeSettings());
    });

    setUp(() {
      firebaseAuth = MockFirebaseAuth();
      googleSignIn = MockGoogleSignIn();
      authorizationCredentialAppleID = MockAuthorizationCredentialAppleID();
      getAppleCredentialsCalls = <List<AppleIDAuthorizationScopes>>[];
      getAppleCredentials = ({
        List<AppleIDAuthorizationScopes> scopes = const [],
        WebAuthenticationOptions? webAuthenticationOptions,
        String? nonce,
        String? state,
      }) async {
        getAppleCredentialsCalls.add(scopes);
        return authorizationCredentialAppleID;
      };
      facebookAuth = MockFacebookAuth();
      twitterLogin = MockTwitterLogin();
      firebaseAuthenticationClient = FirebaseAuthenticationClient(
        firebaseAuth: firebaseAuth,
        googleSignIn: googleSignIn,
        getAppleCredentials: getAppleCredentials,
        facebookAuth: facebookAuth,
        twitterLogin: twitterLogin,
      );
    });

    test('creates FirebaseAuth instance internally when not injected', () {
      expect(() => FirebaseAuthenticationClient(), isNot(throwsException));
    });

    group('logInWithApple', () {
      setUp(() {
        when(() => firebaseAuth.signInWithCredential(any()))
            .thenAnswer((_) => Future.value(MockUserCredential()));
        when(() => authorizationCredentialAppleID.identityToken).thenReturn('');
        when(() => authorizationCredentialAppleID.authorizationCode)
            .thenReturn('');
      });

      test('calls getAppleCredentials with correct scopes', () async {
        await firebaseAuthenticationClient.logInWithApple();
        expect(getAppleCredentialsCalls, [
          [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ]
        ]);
      });

      test('calls signInWithCredential with correct credential', () async {
        const identityToken = 'identity-token';
        const accessToken = 'access-token';
        when(() => authorizationCredentialAppleID.identityToken)
            .thenReturn(identityToken);
        when(() => authorizationCredentialAppleID.authorizationCode)
            .thenReturn(accessToken);
        await firebaseAuthenticationClient.logInWithApple();
        verify(() => firebaseAuth.signInWithCredential(any())).called(1);
      });

      test('throws LogInWithAppleFailure when exception occurs', () async {
        when(() => firebaseAuth.signInWithCredential(any()))
            .thenThrow(Exception());
        expect(
          () => firebaseAuthenticationClient.logInWithApple(),
          throwsA(isA<LogInWithAppleFailure>()),
        );
      });
    });

    group('sendPasswordResetEmail', () {
      setUp(() {
        when(
          () => firebaseAuth.sendPasswordResetEmail(email: any(named: 'email')),
        ).thenAnswer((_) => Future.value());
      });

      test('calls sendPasswordResetEmail', () async {
        await firebaseAuthenticationClient.sendPasswordResetEmail(email: email);
        verify(() => firebaseAuth.sendPasswordResetEmail(email: email))
            .called(1);
      });

      test('succeeds when sendPasswordResetEMail succeeds', () async {
        expect(
          firebaseAuthenticationClient.sendPasswordResetEmail(email: email),
          completes,
        );
      });

      test(
        'throws ResetPasswordFailure when sendPasswordResetEmail throws',
        () async {
          final firebaseAuthExceptions = {
            'invalid-email': ResetPasswordInvalidEmailFailure(
              Exception(),
              StackTrace.current,
            ),
            'user-not-found': ResetPasswordUserNotFoundFailure(
              Exception(),
              StackTrace.current,
            ),
            'default': ResetPasswordFailure(Exception(), StackTrace.current),
          };

          for (final exception in firebaseAuthExceptions.entries) {
            when(
              () => firebaseAuth.sendPasswordResetEmail(
                email: any(named: 'email'),
              ),
            ).thenThrow(
              firebase_auth.FirebaseAuthException(code: exception.key),
            );

            try {
              await firebaseAuthenticationClient.sendPasswordResetEmail(
                email: email,
              );
            } catch (e) {
              expect(e.toString(), exception.value.toString());
            }
          }
        },
      );

      test('throws ResetPasswordFailure when sendPasswordResetEmail throws',
          () async {
        when(
          () => firebaseAuth.sendPasswordResetEmail(
            email: any(named: 'email'),
          ),
        ).thenThrow(Exception());
        expect(
          firebaseAuthenticationClient.sendPasswordResetEmail(email: email),
          throwsA(isA<ResetPasswordFailure>()),
        );
      });
    });

    group('signUp', () {
      setUp(() {
        when(
          () => firebaseAuth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) => Future.value(MockUserCredential()));
      });

      test('calls createUserWithEmailAndPassword', () async {
        await firebaseAuthenticationClient.signUp(
          email: email,
          password: password,
        );
        verify(
          () => firebaseAuth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          ),
        ).called(1);
      });

      test('succeeds when createUserWithEmailAndPassword succeeds', () async {
        expect(
          firebaseAuthenticationClient.signUp(email: email, password: password),
          completes,
        );
      });

      test('throws correct exception based on error code', () async {
        final firebaseAuthExceptions = {
          'email-already-in-use':
              SignUpEmailInUseFailure(Exception(), StackTrace.current),
          'invalid-email':
              SignUpInvalidEmailFailure(Exception(), StackTrace.current),
          'operation-not-allowed':
              SignUpOperationNotAllowedFailure(Exception(), StackTrace.current),
          'weak-password':
              SignUpWeakPasswordFailure(Exception(), StackTrace.current),
          'default': SignUpFailure(Exception(), StackTrace.current),
        };

        for (final exception in firebaseAuthExceptions.entries) {
          when(
            () => firebaseAuth.createUserWithEmailAndPassword(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          ).thenThrow(firebase_auth.FirebaseAuthException(code: exception.key));

          try {
            await firebaseAuthenticationClient.signUp(
              email: email,
              password: password,
            );
          } catch (e) {
            expect(e.toString(), exception.value.toString());
          }
        }
      });

      test('throws SignUpFailure when createUserWithEmailAndPassword throws',
          () async {
        when(
          () => firebaseAuth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(Exception());
        expect(
          firebaseAuthenticationClient.signUp(email: email, password: password),
          throwsA(isA<SignUpFailure>()),
        );
      });
    });

    group('logInWithGoogle', () {
      const accessToken = 'access-token';
      const idToken = 'id-token';

      setUp(() {
        final googleSignInAuthentication = MockGoogleSignInAuthentication();
        final googleSignInAccount = MockGoogleSignInAccount();
        when(() => googleSignInAuthentication.accessToken)
            .thenReturn(accessToken);
        when(() => googleSignInAuthentication.idToken).thenReturn(idToken);
        when(() => googleSignInAccount.authentication)
            .thenAnswer((_) async => googleSignInAuthentication);
        when(() => googleSignIn.signIn())
            .thenAnswer((_) async => googleSignInAccount);
        when(() => firebaseAuth.signInWithCredential(any()))
            .thenAnswer((_) => Future.value(MockUserCredential()));
      });

      test('calls signIn authentication, and signInWithCredential', () async {
        await firebaseAuthenticationClient.logInWithGoogle();
        verify(() => googleSignIn.signIn()).called(1);
        verify(() => firebaseAuth.signInWithCredential(any())).called(1);
      });

      test('succeeds when signIn succeeds', () {
        expect(firebaseAuthenticationClient.logInWithGoogle(), completes);
      });

      test('throws LogInWithGoogleFailure when exception occurs', () async {
        when(() => firebaseAuth.signInWithCredential(any()))
            .thenThrow(Exception());
        expect(
          firebaseAuthenticationClient.logInWithGoogle(),
          throwsA(isA<LogInWithGoogleFailure>()),
        );
      });

      test('throws LogInWithGoogleCanceled when signIn returns null', () async {
        when(() => googleSignIn.signIn()).thenAnswer((_) async => null);
        expect(
          firebaseAuthenticationClient.logInWithGoogle(),
          throwsA(isA<LogInWithGoogleCanceled>()),
        );
      });
    });

    group('logInWithFacebook', () {
      late facebook_auth.LoginResult loginResult;
      late facebook_auth.AccessToken accessTokenResult;
      const accessToken = 'access-token';

      setUp(() {
        loginResult = MockFacebookLoginResult();
        accessTokenResult = MockFacebookAccessToken();

        when(() => accessTokenResult.token).thenReturn(accessToken);
        when(() => loginResult.accessToken).thenReturn(accessTokenResult);
        when(() => loginResult.status)
            .thenReturn(facebook_auth.LoginStatus.success);
        when(() => facebookAuth.login()).thenAnswer((_) async => loginResult);
        when(() => firebaseAuth.signInWithCredential(any()))
            .thenAnswer((_) => Future.value(MockUserCredential()));
      });

      test('calls login authentication and signInWithCredential', () async {
        await firebaseAuthenticationClient.logInWithFacebook();
        verify(() => facebookAuth.login()).called(1);
        verify(() => firebaseAuth.signInWithCredential(any())).called(1);
      });

      test('succeeds when login succeeds', () {
        expect(firebaseAuthenticationClient.logInWithFacebook(), completes);
      });

      test(
          'throws LogInWithFacebookFailure '
          'when signInWithCredential throws', () async {
        when(() => firebaseAuth.signInWithCredential(any()))
            .thenThrow(Exception());
        expect(
          firebaseAuthenticationClient.logInWithFacebook(),
          throwsA(isA<LogInWithFacebookFailure>()),
        );
      });

      test(
          'throws LogInWithFacebookFailure '
          'when login result status is failed', () async {
        when(() => loginResult.status)
            .thenReturn(facebook_auth.LoginStatus.failed);
        expect(
          firebaseAuthenticationClient.logInWithFacebook(),
          throwsA(isA<LogInWithFacebookFailure>()),
        );
      });

      test(
          'throws LogInWithFacebookFailure '
          'when login result access token is empty', () async {
        when(() => loginResult.accessToken).thenReturn(null);
        expect(
          firebaseAuthenticationClient.logInWithFacebook(),
          throwsA(isA<LogInWithFacebookFailure>()),
        );
      });

      test(
          'throws LogInWithFacebookCanceled '
          'when login result status is cancelled', () async {
        when(() => loginResult.status)
            .thenReturn(facebook_auth.LoginStatus.cancelled);
        expect(
          firebaseAuthenticationClient.logInWithFacebook(),
          throwsA(isA<LogInWithFacebookCanceled>()),
        );
      });
    });

    group('logInWithTwitter', () {
      late twitter_auth.AuthResult loginResult;
      const accessToken = 'access-token';
      const secret = 'secret';

      setUp(() {
        loginResult = MockTwitterAuthResult();

        when(() => loginResult.authToken).thenReturn(accessToken);
        when(() => loginResult.authTokenSecret).thenReturn(secret);
        when(() => loginResult.status)
            .thenReturn(twitter_auth.TwitterLoginStatus.loggedIn);
        when(() => twitterLogin.loginV2()).thenAnswer((_) async => loginResult);
        when(() => firebaseAuth.signInWithCredential(any()))
            .thenAnswer((_) => Future.value(MockUserCredential()));
      });

      test('calls loginV2 authentication and signInWithCredential', () async {
        await firebaseAuthenticationClient.logInWithTwitter();
        verify(() => twitterLogin.loginV2()).called(1);
        verify(() => firebaseAuth.signInWithCredential(any())).called(1);
      });

      test('succeeds when login succeeds', () {
        expect(firebaseAuthenticationClient.logInWithTwitter(), completes);
      });

      test(
          'throws LogInWithTwitterFailure '
          'when signInWithCredential throws', () async {
        when(() => firebaseAuth.signInWithCredential(any()))
            .thenThrow(Exception());
        expect(
          firebaseAuthenticationClient.logInWithTwitter(),
          throwsA(isA<LogInWithTwitterFailure>()),
        );
      });

      test(
          'throws LogInWithTwitterFailure '
          'when login result status is error', () async {
        when(() => loginResult.status)
            .thenReturn(twitter_auth.TwitterLoginStatus.error);
        expect(
          firebaseAuthenticationClient.logInWithTwitter(),
          throwsA(isA<LogInWithTwitterFailure>()),
        );
      });

      test(
          'throws LogInWithTwitterFailure '
          'when login result auth token is empty', () async {
        when(() => loginResult.authToken).thenReturn(null);
        expect(
          firebaseAuthenticationClient.logInWithTwitter(),
          throwsA(isA<LogInWithTwitterFailure>()),
        );
      });

      test(
          'throws LogInWithTwitterFailure '
          'when login result auth token secret is empty', () async {
        when(() => loginResult.authTokenSecret).thenReturn(null);
        expect(
          firebaseAuthenticationClient.logInWithTwitter(),
          throwsA(isA<LogInWithTwitterFailure>()),
        );
      });

      test(
          'throws LogInWithTwitterCanceled '
          'when login result status is cancelledByUser', () async {
        when(() => loginResult.status)
            .thenReturn(twitter_auth.TwitterLoginStatus.cancelledByUser);
        expect(
          firebaseAuthenticationClient.logInWithTwitter(),
          throwsA(isA<LogInWithTwitterCanceled>()),
        );
      });
    });

    group('logInWithEmailAndPassword', () {
      setUp(() {
        when(
          () => firebaseAuth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) => Future.value(MockUserCredential()));
      });

      test('calls signInWithEmailAndPassword', () async {
        await firebaseAuthenticationClient.logInWithEmailAndPassword(
          email: email,
          password: password,
        );
        verify(
          () => firebaseAuth.signInWithEmailAndPassword(
            email: email,
            password: password,
          ),
        ).called(1);
      });

      test('succeeds when signInWithEmailAndPassword succeeds', () async {
        expect(
          firebaseAuthenticationClient.logInWithEmailAndPassword(
            email: email,
            password: password,
          ),
          completes,
        );
      });

      test(
          'throws LogInWithEmailAndPasswordFailure '
          'when signInWithEmailAndPassword throws', () async {
        when(
          () => firebaseAuth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(Exception());
        expect(
          firebaseAuthenticationClient.logInWithEmailAndPassword(
            email: email,
            password: password,
          ),
          throwsA(isA<LogInWithEmailAndPasswordFailure>()),
        );
      });
    });

    group('sendLoginEmailLink', () {
      setUp(() {
        when(
          () => firebaseAuth.sendSignInLinkToEmail(
            email: any(named: 'email'),
            actionCodeSettings: any(named: 'actionCodeSettings'),
          ),
        ).thenAnswer((_) async {});
      });

      test('calls sendSignInLinkToEmail', () async {
        await firebaseAuthenticationClient.sendLoginEmailLink(
          email: email,
          appPackageName: appPackageName,
        );

        verify(
          () => firebaseAuth.sendSignInLinkToEmail(
            email: email,
            actionCodeSettings: any(
              named: 'actionCodeSettings',
              that: isA<firebase_auth.ActionCodeSettings>()
                  .having(
                    (settings) => settings.androidPackageName,
                    'androidPackageName',
                    equals(appPackageName),
                  )
                  .having(
                    (settings) => settings.iOSBundleId,
                    'iOSBundleId',
                    equals(appPackageName),
                  )
                  .having(
                    (settings) => settings.androidInstallApp,
                    'androidInstallApp',
                    isTrue,
                  )
                  .having(
                    (settings) => settings.handleCodeInApp,
                    'handleCodeInApp',
                    isTrue,
                  ),
            ),
          ),
        ).called(1);
      });

      test('succeeds when sendSignInLinkToEmail succeeds', () async {
        expect(
          firebaseAuthenticationClient.sendLoginEmailLink(
            email: email,
            appPackageName: appPackageName,
          ),
          completes,
        );
      });

      test(
          'throws SendLoginEmailLinkFailure '
          'when sendSignInLinkToEmail throws', () async {
        when(
          () => firebaseAuth.sendSignInLinkToEmail(
            email: any(named: 'email'),
            actionCodeSettings: any(named: 'actionCodeSettings'),
          ),
        ).thenThrow(Exception());
        expect(
          firebaseAuthenticationClient.sendLoginEmailLink(
            email: email,
            appPackageName: appPackageName,
          ),
          throwsA(isA<SendLoginEmailLinkFailure>()),
        );
      });
    });

    group('isLogInWithEmailLink', () {
      setUp(() {
        when(
          () => firebaseAuth.isSignInWithEmailLink(any()),
        ).thenAnswer((_) => true);
      });

      test('calls isSignInWithEmailLink', () {
        firebaseAuthenticationClient.isLogInWithEmailLink(
          emailLink: emailLink,
        );
        verify(
          () => firebaseAuth.isSignInWithEmailLink(emailLink),
        ).called(1);
      });

      test('succeeds when isSignInWithEmailLink succeeds', () async {
        expect(
          firebaseAuthenticationClient.isLogInWithEmailLink(
            emailLink: emailLink,
          ),
          isTrue,
        );
      });

      test(
          'throws IsLogInWithEmailLinkFailure '
          'when isSignInWithEmailLink throws', () async {
        when(
          () => firebaseAuth.isSignInWithEmailLink(any()),
        ).thenThrow(Exception());
        expect(
          () => firebaseAuthenticationClient.isLogInWithEmailLink(
            emailLink: emailLink,
          ),
          throwsA(isA<IsLogInWithEmailLinkFailure>()),
        );
      });
    });

    group('logInWithEmailLink', () {
      setUp(() {
        when(
          () => firebaseAuth.signInWithEmailLink(
            email: any(named: 'email'),
            emailLink: any(named: 'emailLink'),
          ),
        ).thenAnswer((_) => Future.value(MockUserCredential()));
      });

      test('calls signInWithEmailLink', () async {
        await firebaseAuthenticationClient.logInWithEmailLink(
          email: email,
          emailLink: emailLink,
        );
        verify(
          () => firebaseAuth.signInWithEmailLink(
            email: email,
            emailLink: emailLink,
          ),
        ).called(1);
      });

      test('succeeds when signInWithEmailLink succeeds', () async {
        expect(
          firebaseAuthenticationClient.logInWithEmailLink(
            email: email,
            emailLink: emailLink,
          ),
          completes,
        );
      });

      test(
          'throws LogInWithEmailLinkFailure '
          'when signInWithEmailLink throws', () async {
        when(
          () => firebaseAuth.signInWithEmailLink(
            email: any(named: 'email'),
            emailLink: any(named: 'emailLink'),
          ),
        ).thenThrow(Exception());
        expect(
          firebaseAuthenticationClient.logInWithEmailLink(
            email: email,
            emailLink: emailLink,
          ),
          throwsA(isA<LogInWithEmailLinkFailure>()),
        );
      });
    });

    group('logOut', () {
      test('calls signOut', () async {
        when(() => firebaseAuth.signOut()).thenAnswer((_) async {});
        when(() => googleSignIn.signOut()).thenAnswer((_) async => null);
        await firebaseAuthenticationClient.logOut();
        verify(() => firebaseAuth.signOut()).called(1);
        verify(() => googleSignIn.signOut()).called(1);
      });

      test('throws LogOutFailure when signOut throws', () async {
        when(() => firebaseAuth.signOut()).thenThrow(Exception());
        expect(
          firebaseAuthenticationClient.logOut(),
          throwsA(isA<LogOutFailure>()),
        );
      });
    });

    group('user', () {
      const userId = 'mock-uid';
      const email = 'mock-email';
      const newUser = User(id: userId, email: email);
      const returningUser = User(id: userId, email: email, isNewUser: false);
      test('emits User.anonymous when firebase user is null', () async {
        when(() => firebaseAuth.authStateChanges()).thenAnswer(
          (_) => Stream.value(null),
        );
        await expectLater(
          firebaseAuthenticationClient.user,
          emitsInOrder(const <User>[User.anonymous]),
        );
      });

      test('emits new user when firebase user is not null', () async {
        final firebaseUser = MockFirebaseUser();
        final userMetadata = MockUserMetadata();
        final creationTime = DateTime(2020);
        when(() => firebaseUser.uid).thenReturn(userId);
        when(() => firebaseUser.email).thenReturn(email);
        when(() => userMetadata.creationTime).thenReturn(creationTime);
        when(() => userMetadata.lastSignInTime).thenReturn(creationTime);
        when(() => firebaseUser.photoURL).thenReturn(null);
        when(() => firebaseUser.metadata).thenReturn(userMetadata);
        when(() => firebaseAuth.authStateChanges()).thenAnswer(
          (_) => Stream.value(firebaseUser),
        );
        await expectLater(
          firebaseAuthenticationClient.user,
          emitsInOrder(const <User>[newUser]),
        );
      });

      test('emits new user when firebase user is not null', () async {
        final firebaseUser = MockFirebaseUser();
        final userMetadata = MockUserMetadata();
        final creationTime = DateTime(2020);
        final lastSignInTime = DateTime(2019);
        when(() => firebaseUser.uid).thenReturn(userId);
        when(() => firebaseUser.email).thenReturn(email);
        when(() => userMetadata.creationTime).thenReturn(creationTime);
        when(() => userMetadata.lastSignInTime).thenReturn(lastSignInTime);
        when(() => firebaseUser.photoURL).thenReturn(null);
        when(() => firebaseUser.metadata).thenReturn(userMetadata);
        when(() => firebaseAuth.authStateChanges()).thenAnswer(
          (_) => Stream.value(firebaseUser),
        );
        await expectLater(
          firebaseAuthenticationClient.user,
          emitsInOrder(const <User>[returningUser]),
        );
      });
    });
  });
}
